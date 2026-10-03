extends SceneTree

const MARKET = preload("res://scripts/EquipmentMarketService.gd")
const RULES = preload("res://scripts/EquipmentRules.gd")
var checks := 0
var failures: Array[String] = []
var sequence := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _gear(item_id: String, overrides: Dictionary = {}) -> Dictionary:
	var raw := {"id": item_id, "name": "초원 별의 활", "slot": "weapon", "rarity": "전설", "level": 4, "set": "개척자", "zone": "회색 초원", "origin": "hunt", "source_id": "gray_meadow", "affixes": [{"stat": "attack_pct", "value": 4}], "focus": 2}
	raw.merge(overrides, true)
	return RULES.normalize(raw)

func _fixture(items: Array = []) -> RefCounted:
	var market := MARKET.new()
	_check(market.bootstrap_account("seller", 5000, items, "판매자")["ok"], "bootstrap seller")
	_check(market.bootstrap_account("buyer", 4000, [], "구매자")["ok"], "bootstrap buyer")
	_check(market.bootstrap_account("buyer2", 4000, [], "구매자 2")["ok"], "bootstrap competing buyer")
	return market

func _submit(market, actor: String, action: String, details: Dictionary = {}, now: int = 1000) -> Dictionary:
	sequence += 1
	var command := {"request_id": "test_request_%d" % sequence, "action": action}
	command.merge(details, true)
	return market.submit(actor, command, now)

func _list(market, item_id: String, price: int = 1000, now: int = 1000) -> String:
	var response := _submit(market, "seller", "list", {"item_id": item_id, "price": price}, now)
	_check(response["ok"], "list %s" % item_id)
	return str(response.get("listing_id", ""))

func _money(market) -> int:
	var total := 0
	for account in market.accounts.values():
		total += int(account["gold"]) + int(account["pending_gold"])
	return total

func _assert_unique(market, label: String) -> void:
	var seen := {}
	var duplicate := false
	for account in market.accounts.values():
		for field in ["inventory", "deliveries"]:
			for item in account[field]:
				duplicate = duplicate or seen.has(item["id"])
				seen[item["id"]] = true
	for listing in market.listings.values():
		if listing["status"] == "active":
			duplicate = duplicate or seen.has(listing["item"]["id"])
			seen[listing["item"]["id"]] = true
	_check(not duplicate, label)

func _lifecycle() -> void:
	var original := _gear("lifecycle")
	var market = _fixture([original])
	var before := _money(market)
	var listing_id := _list(market, "lifecycle", 1001)
	_check(market.account_snapshot("seller")["inventory"].is_empty(), "listing escrows the actual equipment")
	_check(_money(market) == before, "listing is free")
	_check(not _submit(market, "seller", "buy", {"listing_id": listing_id})["ok"], "self buying is forbidden")
	_check(not _submit(market, "buyer", "cancel", {"listing_id": listing_id})["ok"], "another account cannot cancel escrow")
	var command := {"request_id": "buy_once", "action": "buy", "listing_id": listing_id}
	var response: Dictionary = market.submit("buyer", command, 1001)
	_check(response["ok"] and response["fee"] == 51 and response["proceeds"] == 950, "sale rounds a five percent fee up exactly")
	_check(_money(market) == before - 51, "buy conserves all gold except the documented fee")
	var buyer: Dictionary = market.account_snapshot("buyer")
	var seller: Dictionary = market.account_snapshot("seller")
	_check(buyer["gold"] == 2999 and buyer["inventory"].is_empty() and buyer["deliveries"].size() == 1, "buyer pays once and gets delivery")
	_check(seller["gold"] == 5000 and seller["pending_gold"] == 950, "seller proceeds await settlement")
	var delivered: Dictionary = buyer["deliveries"][0]
	_check(delivered["bound"] and delivered["trade_count"] == 1, "purchased gear is bound after one trade")
	for field in ["id", "level", "focus", "set", "origin", "source_id"]:
		_check(delivered[field] == original[field], "trade preserves %s" % field)
	_check(delivered["affixes"].size() == original["affixes"].size(), "trade preserves affix count")
	for affix_index in original["affixes"].size():
		var previous: Dictionary = original["affixes"][affix_index]
		var current: Dictionary = delivered["affixes"][affix_index]
		_check(previous["stat"] == current["stat"] and previous["value"] == current["value"] and current["trade_count"] == 1, "purchased affix preserves exact roll and carries a permanent trade history")
	_check(not _submit(market, "buyer2", "buy", {"listing_id": listing_id})["ok"], "competing buyer cannot buy sold equipment")
	_check(market.account_snapshot("buyer2")["gold"] == 4000, "losing buyer never pays")
	var duplicate: Dictionary = market.submit("buyer", command, 1002)
	_check(duplicate["ok"] and duplicate["duplicate"] and _money(market) == before - 51, "identical buy retry returns its receipt without another debit")
	command["listing_id"] = "different"
	_check(not market.submit("buyer", command, 1002)["ok"], "changed payload cannot reuse a request ID")
	_check(_submit(market, "buyer", "claim", {"item_id": "lifecycle"})["ok"], "buyer receives requested item")
	_check(_submit(market, "seller", "claim", {"gold_only": true})["claimed_gold"] == 950, "seller receives exact net proceeds")
	_check(market.account_snapshot("seller")["gold"] == 5950 and market.account_snapshot("seller")["pending_gold"] == 0, "settlement transfers without minting")
	_check(not _submit(market, "buyer", "list", {"item_id": "lifecycle", "price": 1000})["ok"], "purchased gear cannot be resold")
	_check(not _submit(market, "seller", "claim", {"gold_only": true})["ok"], "settlement cannot be claimed twice")
	_assert_unique(market, "sale and claims retain one global equipment owner")

func _cancel_and_expiry() -> void:
	var market = _fixture([_gear("cancel"), _gear("expiry")])
	var before := _money(market)
	var listing_id := _list(market, "cancel")
	_check(_submit(market, "seller", "cancel", {"listing_id": listing_id})["ok"], "seller can cancel")
	_check(not _submit(market, "seller", "cancel", {"listing_id": listing_id})["ok"], "second cancellation cannot duplicate the item")
	_check(_money(market) == before, "cancellation is free")
	_check(market.account_snapshot("seller")["deliveries"].size() == 1, "cancellation returns one item to delivery")
	_check(_submit(market, "seller", "claim", {"item_id": "cancel"})["ok"], "cancelled equipment is recoverable")
	var relisted := _list(market, "cancel")
	_check(relisted != listing_id, "cancelled item may be relisted with a new listing ID")
	var expired := _list(market, "expiry")
	_check(market.expire(1000 + MARKET.LISTING_DURATION - 1) == 0, "offer remains live before 48 hour deadline")
	_check(market.expire(1000 + MARKET.LISTING_DURATION) == 2, "deadline expires both active offers")
	_check(market.expire(1000 + MARKET.LISTING_DURATION + 1) == 0, "expiration is idempotent")
	_check(market.account_snapshot("seller")["deliveries"].size() == 2, "expired escrow is preserved for seller")
	_check(not _submit(market, "buyer", "buy", {"listing_id": expired}, 1000 + MARKET.LISTING_DURATION)["ok"], "expired offer cannot sell")
	_check(_money(market) == before, "expired orders never change money")
	_assert_unique(market, "cancellation and expiration retain one owner")

func _capacity_and_sync() -> void:
	var market = _fixture([_gear("delivery")])
	var full_bag: Array = []
	for index in MARKET.INVENTORY_CAP:
		full_bag.append(_gear("full_%d" % index))
	_check(market.sync_local_account("buyer", 4000, full_bag)["ok"], "trusted local adapter accepts a full real bag")
	var listing_id := _list(market, "delivery")
	_check(_submit(market, "buyer", "buy", {"listing_id": listing_id})["ok"], "full bag can buy safely into delivery")
	_check(not _submit(market, "buyer", "claim", {"item_id": "delivery"})["ok"], "full bag cannot consume a delivery")
	_check(market.account_snapshot("buyer")["deliveries"].size() == 1, "failed claim retains the full equipment")
	full_bag.pop_back()
	_check(market.sync_local_account("buyer", 3000, full_bag)["ok"], "local inventory can free a space")
	_check(_submit(market, "buyer", "claim", {"item_id": "delivery"})["ok"], "delivery remains claimable after space is freed")
	_check(market.account_snapshot("buyer")["inventory"].size() == MARKET.INVENTORY_CAP, "claim respects shared inventory capacity")
	_check(not market.sync_local_account("seller", 5000, [_gear("delivery")])["ok"], "trusted sync still rejects another owner's equipment ID")
	_check(not market.bootstrap_account("duplicate", 0, [_gear("delivery")])["ok"], "bootstrap cannot create duplicate global gear IDs")
	_assert_unique(market, "capacity flow retains one owner")

func _rules_and_validation() -> void:
	var cases := [{"locked": true}, {"bound": true}, {"trade_count": 1}, {"set": "초보자"}, {"proposal": {"family": "guard", "options": [{"stat": "hp_pct", "value": 4}], "cost": 20}}]
	var items: Array = []
	for index in cases.size():
		items.append(_gear("restricted_%d" % index, cases[index]))
	items.append(_gear("valid"))
	var market = _fixture(items)
	for index in cases.size():
		_check(not _submit(market, "seller", "list", {"item_id": "restricted_%d" % index, "price": 10})["ok"], "trade restriction %d cannot enter escrow" % index)
	for price in [0, -10, 9, 10.5, "10", true, null, 1000000001, INF, NAN]:
		_check(not _submit(market, "seller", "list", {"item_id": "valid", "price": price})["ok"], "reject invalid price %s" % str(price))
	_check(market.account_snapshot("seller")["inventory"].size() == 6, "validation failures leave all equipment in bag")
	var expected_revision: int = market.revision
	_check(not _submit(market, "seller", "list", {"item_id": "valid", "price": 10, "expected_revision": expected_revision - 1})["ok"], "stale revision cannot mutate ownership")
	_check(_submit(market, "seller", "list", {"item_id": "valid", "price": 10, "expected_revision": expected_revision})["ok"], "current revision can register")
	_check(not market.sync_local_account("seller", 5000, [_gear("valid")])["ok"], "stale local bag cannot reintroduce escrowed item")
	_check(not _submit(market, "buyer", "claim", {"gold_only": "true"})["ok"], "claim requires an actual boolean")
	_check(not market.submit("buyer", {"action": "claim"}, 1000)["ok"], "missing request ID rejected")
	_check(not _submit(market, "missing", "claim")["ok"], "unknown actor cannot transact")
	_check(not _submit(market, "buyer", "claim", {}, -1)["ok"], "negative time rejected")
	var stale := {"request_id": "rejected_receipt", "action": "buy", "listing_id": "missing"}
	_check(not market.submit("buyer", stale, 1000)["ok"], "failed request produces a rejection receipt")
	_check(market.submit("buyer", stale, 1000).get("duplicate", false), "rejected request also deduplicates")
	var snapshot: Dictionary = market.account_snapshot("seller")
	snapshot["gold"] = 99999
	snapshot["inventory"].clear()
	var offers: Array = market.browse()
	offers[0]["price"] = 1
	offers[0]["item"]["level"] = 10
	var exported: Dictionary = market.to_dict()
	exported["accounts"].clear()
	_check(market.account_snapshot("seller")["gold"] == 5000 and market.account_snapshot("seller")["inventory"].size() == 5, "account snapshots are detached copies")
	_check(market.browse()[0]["price"] == 10 and market.browse()[0]["item"]["level"] == 4, "public listings are detached copies")
	_check(market.accounts.size() == 3, "exported save cannot mutate service")

func _limits_and_overflow() -> void:
	var items: Array = []
	for index in 6:
		items.append(_gear("cap_%d" % index))
	var market = _fixture(items)
	for index in 5:
		_list(market, "cap_%d" % index)
	_check(not _submit(market, "seller", "list", {"item_id": "cap_5", "price": 100})["ok"], "at most five concurrent sales")
	_check(market.browse("seller").size() == 5 and market.browse("buyer").is_empty(), "owner filter exposes only owned listings")
	var money_market = _fixture([_gear("overflow")])
	_check(money_market.sync_local_account("seller", MARKET.MAX_CURRENCY - 1, [_gear("overflow")])["ok"], "prepare a near-cap seller")
	var listing_id := _list(money_market, "overflow", 10)
	var before := _money(money_market)
	_check(not _submit(money_market, "buyer", "buy", {"listing_id": listing_id})["ok"], "seller currency overflow rejects entire transaction")
	_check(_money(money_market) == before and money_market.account_snapshot("buyer")["deliveries"].is_empty() and money_market.browse().size() == 1, "overflow never debits buyer or transfers gear")
	_check(money_market.sync_local_account("seller", MARKET.MAX_CURRENCY - 9, [])["ok"], "seller can make exactly enough settlement space")
	_check(_submit(money_market, "buyer", "buy", {"listing_id": listing_id})["fee"] == 1, "minimum sale charges one gold")
	_check(not money_market.sync_local_account("seller", MARKET.MAX_CURRENCY, [])["ok"], "local sync includes unsettled gold in total cap")
	_check(_submit(money_market, "seller", "claim", {"gold_only": true})["ok"], "exact currency cap settlement succeeds")
	_check(money_market.account_snapshot("seller")["gold"] == MARKET.MAX_CURRENCY, "settlement reaches cap without overflow")

func _persistence_and_hostile_state() -> void:
	var market = _fixture([_gear("saved_buy"), _gear("saved_expiry")])
	var listing_id := _list(market, "saved_buy", 121)
	var buy_command := {"request_id": "persist_buy", "action": "buy", "listing_id": listing_id}
	_check(market.submit("buyer", buy_command, 1001)["ok"], "prepare completed sale to reload")
	_list(market, "saved_expiry")
	var copy := MARKET.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(market.to_dict())))
	_check(copy.to_dict() == market.to_dict(), "JSON roundtrip preserves entire market state")
	var before: Dictionary = copy.account_snapshot("buyer")
	_check(copy.submit("buyer", buy_command, 1002).get("duplicate", false), "purchase receipt survives a restart")
	_check(copy.account_snapshot("buyer") == before, "reloaded retry cannot deliver or debit twice")
	_check(copy.expire(1000 + MARKET.LISTING_DURATION) == 1, "reloaded escrow still expires")
	var restored := MARKET.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(copy.to_dict())))
	_check(restored.account_snapshot("seller")["deliveries"].size() == 1 and restored.account_snapshot("buyer")["deliveries"].size() == 1, "both sale and expiration deliveries survive restart")
	_check(_submit(restored, "seller", "claim")["ok"], "reloaded seller can receive expired gear and proceeds together")
	_check(_submit(restored, "buyer", "claim")["ok"], "reloaded buyer can receive purchase")
	_assert_unique(restored, "persisted market retains unique ownership")
	var hostile: Dictionary = market.to_dict()
	hostile["accounts"]["seller"]["gold"] = "9999999"
	hostile["accounts"]["seller"]["pending_gold"] = INF
	hostile["accounts"]["seller"]["name"] = {"bad": true}
	hostile["accounts"]["seller"]["deliveries"] = [_gear("saved_expiry"), _gear("dupe")]
	hostile["accounts"]["buyer"]["inventory"] = [_gear("dupe"), null, {"id": "bad", "slot": "bad"}]
	hostile["accounts"]["bad"] = []
	hostile["processed_commands"]["bad"] = {"response": []}
	copy.from_dict(hostile)
	_check(copy.account_snapshot("seller")["gold"] == 0 and copy.account_snapshot("seller")["pending_gold"] == 0, "malformed currencies cannot mint gold on import")
	_check(not copy.accounts.has("bad"), "malformed accounts are skipped")
	_check(copy.account_snapshot("seller")["deliveries"].size() == 1 and copy.account_snapshot("buyer")["inventory"].is_empty(), "active escrow then deliveries take precedence over duplicate inventories")
	_assert_unique(copy, "hostile imported ownership is unique")
	var local := MARKET.new()
	_check(local.bootstrap_account("player_local", 5, [_gear("canonical")])["ok"], "prepare local canonical account")
	_check(local.bootstrap_account("peer", 5, [_gear("external")])["ok"], "prepare peer equipment")
	var peer_sale := _submit(local, "peer", "list", {"item_id": "external", "price": 10})
	_check(peer_sale["ok"], "prepare conflicting external escrow fixture")
	local.from_dict(local.to_dict(), ["canonical", "external"])
	_check(local.account_snapshot("player_local")["inventory"].size() == 1, "canonical Main bag permits its local account mirror")
	_check(local.browse().is_empty() and local.account_snapshot("peer")["deliveries"].is_empty(), "external owned equipment cancels stale escrow without generating a duplicate delivery")
	copy.from_dict({"market_version": 999, "accounts": market.accounts})
	_check(copy.accounts.is_empty() and not copy.load_warning.is_empty(), "unsupported state version is not interpreted as current data")

func _sequence_recovery_at_history_limit() -> void:
	var market = _fixture([_gear("history_return"), _gear("history_sell")])
	var return_id := _list(market, "history_return")
	var sold_id := _list(market, "history_sell", 100)
	_check(_submit(market, "buyer", "buy", {"listing_id": sold_id})["ok"], "history-limit fixture has pending proceeds and a bought delivery")
	# Fill the old random-ID protocol using real rejected commands. These consume
	# history but never create money/items; successful old receipts must not replay.
	var first_rejected := {"request_id": "history_0", "action": "unsupported"}
	var index := 0
	while market.processed_commands.size() < MARKET.RECEIPT_CAP:
		market.submit("seller", {"request_id": "history_%d" % index, "action": "unsupported"}, 1000)
		index += 1
	_check(not market.submit("seller", {"request_id": "over_limit", "action": "claim"}, 1000)["ok"], "exhausted random-ID protocol asks for a sequenced request")
	var cancel := {"request_id": "seq_1", "request_seq": 1, "action": "cancel", "listing_id": return_id}
	_check(market.submit("seller", cancel, 1000)["ok"], "history cap never prevents owner cancellation through sequenced protocol")
	_check(market.legacy_requests_closed and market.processed_commands.size() <= MARKET.RECEIPT_CAP, "legacy protocol closes before old receipts are pruned")
	var claim := {"request_id": "seq_2", "request_seq": 2, "action": "claim"}
	var claimed: Dictionary = market.submit("seller", claim, 1000)
	_check(claimed["ok"] and claimed["claimed_gold"] == 95 and claimed["claimed_items"] == 1, "at history cap owner still recovers both escrow and settlement")
	_check(market.submit("buyer", {"request_id": "seq_1", "request_seq": 1, "action": "claim"}, 1000)["ok"], "at history cap buyer still receives equipment")
	var seller_after: Dictionary = market.account_snapshot("seller")
	_check(market.submit("seller", claim, 1000).get("duplicate", false), "recent sequenced claim returns its saved receipt")
	_check(not market.submit("seller", {"request_id": "seq_2", "request_seq": 3, "action": "claim"}, 1000)["ok"], "old request ID cannot be attached to a fresh sequence")
	for number in range(3, 100):
		market.submit("seller", {"request_id": "seq_%d" % number, "request_seq": number, "action": "claim"}, 1000)
	var seller_receipts := 0
	for receipt in market.processed_commands.values():
		if receipt["actor_id"] == "seller" and int(receipt.get("request_seq", 0)) > 0:
			seller_receipts += 1
	_check(seller_receipts == MARKET.SEQUENCED_RECEIPTS_PER_ACCOUNT and market.processed_commands.size() <= MARKET.RECEIPT_CAP, "sequenced replay window stays bounded during long play")
	_check(not market.submit("seller", claim, 1000)["ok"], "pruned old sequence is rejected instead of re-executed")
	_check(market.account_snapshot("seller")["gold"] == seller_after["gold"] and market.account_snapshot("seller")["inventory"] == seller_after["inventory"], "receipt pruning never changes assets")
	var restored := MARKET.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(market.to_dict())))
	_check(restored.account_snapshot("seller")["last_request_seq"] == 99 and restored.legacy_requests_closed, "replay high-water and legacy closure survive save roundtrip")
	_check(not restored.submit("seller", cancel, 1000)["ok"] and not restored.submit("seller", first_rejected, 1000)["ok"], "restart never replays old sequence or closed legacy request")
	var next_list := {"request_id": "seq_100", "request_seq": 100, "action": "list", "item_id": "history_return", "price": 100}
	var listed: Dictionary = restored.submit("seller", next_list, 1000)
	_check(listed["ok"], "long-running sequenced market can still create legitimate new sales")
	_check(restored.expire(1000 + MARKET.LISTING_DURATION) == 1, "history cap cannot prevent expiry")
	_check(restored.submit("seller", {"request_id": "seq_101", "request_seq": 101, "action": "claim"}, 1000 + MARKET.LISTING_DURATION)["ok"], "expired equipment remains recoverable after bounded history restart")
	_assert_unique(restored, "history-limit recovery preserves globally unique gear")

func _option_crystal_trade() -> void:
	var crystal := RULES.normalize({"id": "crystal_original", "item_type": "option_crystal", "name": "공격력 옵션 결정", "slot": "accessory", "set": "초보자", "rarity": "희귀", "origin": "hunt", "source_id": "gray_meadow", "stored_option": {"stat": "attack_pct", "value": 4}})
	_check(crystal.get("item_type") == "option_crystal" and RULES.tradable(crystal), "extracted untraded crystal is a tradable non-equipment item")
	var market = _fixture([crystal])
	var listing_id := _list(market, "crystal_original", 129)
	_check(not _submit(market, "seller", "buy", {"listing_id": listing_id})["ok"], "crystals obey self-trade restrictions")
	var before := _money(market)
	var failed: Dictionary = _submit(market, "buyer", "buy", {"listing_id": listing_id, "expected_revision": market.revision - 1})
	_check(not failed["ok"] and _money(market) == before and market.browse()[0]["item"]["stored_option"]["value"] == 4, "rejected crystal purchase preserves money and the original option roll")
	var bought: Dictionary = _submit(market, "buyer", "buy", {"listing_id": listing_id})
	_check(bought["ok"] and bought["fee"] == 7 and bought["proceeds"] == 122, "crystal sale uses the same transparent rounded fee")
	_check(_money(market) == before - 7, "crystal trading cannot create gold")
	var delivered: Dictionary = market.account_snapshot("buyer")["deliveries"][0]
	_check(delivered["stored_option"]["stat"] == "attack_pct" and delivered["stored_option"]["value"] == 4, "crystal delivery preserves option identity and exact roll")
	_check(delivered["stored_option"]["trade_count"] == 1 and delivered["bound"] and delivered["trade_count"] == 1, "crystal and its contained option both carry one-trade history")
	_check(not _submit(market, "buyer2", "buy", {"listing_id": listing_id})["ok"], "crystal ownership can transfer only once")
	var full_bag: Array = []
	for index in MARKET.INVENTORY_CAP:
		full_bag.append(_gear("crystal_bag_%d" % index))
	_check(market.sync_local_account("buyer", 3871, full_bag)["ok"], "prepare full bag while crystal stays in delivery")
	_check(not _submit(market, "buyer", "claim", {"item_id": "crystal_original"})["ok"], "full bag crystal claim fails without consuming it")
	_check(market.account_snapshot("buyer")["deliveries"][0] == delivered, "failed crystal claim preserves complete item and trade metadata")
	full_bag.pop_back()
	_check(market.sync_local_account("buyer", 3871, full_bag)["ok"] and _submit(market, "buyer", "claim", {"item_id": "crystal_original"})["ok"], "crystal remains claimable after space is freed")
	_check(not _submit(market, "buyer", "list", {"item_id": "crystal_original", "price": 100})["ok"], "purchased crystal cannot be sold again")
	var restored := MARKET.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(market.to_dict())))
	var restored_item: Dictionary = restored.account_snapshot("buyer")["inventory"].back()
	_check(restored_item["stored_option"] == delivered["stored_option"] and restored_item["item_type"] == "option_crystal", "crystal option and trade provenance survive market persistence")
	var rebuilt := restored_item.duplicate(true)
	rebuilt["bound"] = false
	rebuilt["trade_count"] = 0
	_check(not RULES.tradable(rebuilt), "rebuilding a crystal wrapper cannot erase contained-option trade history")
	var purchased_affix := RULES.normalize({"id": "affix_history", "name": "반복 추출 검사", "slot": "weapon", "set": "개척자", "rarity": "희귀", "affixes": [{"stat": "attack_pct", "value": 4, "trade_count": 1}]})
	_check(not RULES.tradable(purchased_affix), "implanting a traded option cannot make another equipment tradeable")
	_assert_unique(restored, "crystal trading preserves one global item owner")

func _run() -> void:
	_lifecycle()
	_cancel_and_expiry()
	_capacity_and_sync()
	_rules_and_validation()
	_limits_and_overflow()
	_persistence_and_hostile_state()
	_sequence_recovery_at_history_limit()
	_option_crystal_trade()
	print("V54EquipmentMarketSmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
