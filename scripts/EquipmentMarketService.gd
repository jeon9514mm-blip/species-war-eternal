extends RefCounted
class_name EquipmentMarketService

# This is a trusted, single-process LOCAL authority. It is not a network login,
# an anti-cheat service, or an invitation to trust a remote client's inventory.
const RULES = preload("res://scripts/EquipmentRules.gd")
const VERSION := 1
const MIN_PRICE := 10
const MAX_PRICE := 1000000000
const MAX_CURRENCY := 1000000000000
const INVENTORY_CAP := RULES.INVENTORY_CAP
const LISTING_CAP := 5
const LISTING_DURATION := 48 * 60 * 60
const DELIVERY_CAP := 512
const ACCOUNT_CAP := 64
const HISTORY_CAP := 2048
const RECEIPT_CAP := 8192
const SEQUENCED_RECEIPTS_PER_ACCOUNT := 64
const MAX_TIMESTAMP := 4102444800

var accounts: Dictionary = {}
var listings: Dictionary = {}
var revision := 0
var next_listing_serial := 1
var processed_commands: Dictionary = {}
var legacy_requests_closed := false
var load_warning := ""

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= float(minimum) and float(value) <= float(maximum) and fmod(float(value), 1.0) == 0.0

func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 120:
		return false
	for character in value:
		if character.unicode_at(0) < 32:
			return false
	return true

func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason, "revision": revision}

func _item(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or not _identifier(raw.get("id")):
		return {}
	return RULES.normalize(raw)

func _owned_ids(except_inventory_owner: String = "") -> Dictionary:
	var owned := {}
	for account_id in accounts:
		var account: Dictionary = accounts[account_id]
		if str(account_id) != except_inventory_owner:
			for item in account["inventory"]:
				owned[str(item["id"])] = true
		for item in account["deliveries"]:
			owned[str(item["id"])] = true
	for listing in listings.values():
		if listing["status"] == "active":
			owned[str(listing["item"]["id"])] = true
	return owned

func _validated_items(raw: Array, owned: Dictionary, maximum: int) -> Dictionary:
	if raw.size() > maximum:
		return {"ok": false, "reason": "장비 보관 한도 초과"}
	var result: Array = []
	for value in raw:
		var item := _item(value)
		if item.is_empty():
			return {"ok": false, "reason": "잘못된 장비 정보"}
		var item_id := str(item["id"])
		if owned.has(item_id):
			return {"ok": false, "reason": "중복 장비 ID"}
		owned[item_id] = true
		result.append(item)
	return {"ok": true, "items": result}

# Privileged setup/migration only. Ordinary trade requests cannot mint accounts,
# money, or equipment. No NPC accounts or fabricated player listings are seeded.
func bootstrap_account(account_id: String, gold: int, items: Array, display_name: String = "", kind: String = "player") -> Dictionary:
	if not _identifier(account_id) or accounts.has(account_id) or accounts.size() >= ACCOUNT_CAP:
		return _result(false, "계정을 추가할 수 없습니다")
	if gold < 0 or gold > MAX_CURRENCY or kind not in ["player", "npc"]:
		return _result(false, "잘못된 계정 정보")
	var validated := _validated_items(items, _owned_ids(), INVENTORY_CAP)
	if not validated["ok"]:
		return _result(false, validated["reason"])
	accounts[account_id] = {"id": account_id, "name": display_name.left(40) if not display_name.is_empty() else account_id.left(40), "kind": kind, "gold": gold, "inventory": validated["items"], "deliveries": [], "pending_gold": 0, "last_request_seq": 0}
	revision += 1
	return _result(true)

# Main owns local hunting/growth rewards. Call before a command, then mirror the
# successful snapshot back and persist BOTH game and market in the same save.
# This trusted adapter must never be exposed as a remote player API.
func sync_local_account(account_id: String, gold: int, items: Array) -> Dictionary:
	if not accounts.has(account_id):
		return bootstrap_account(account_id, gold, items)
	var account: Dictionary = accounts[account_id]
	if gold < 0 or gold > MAX_CURRENCY - int(account["pending_gold"]):
		return _result(false, "골드 보유 한도 초과")
	var validated := _validated_items(items, _owned_ids(account_id), INVENTORY_CAP)
	if not validated["ok"]:
		return _result(false, validated["reason"])
	if int(account["gold"]) != gold or account["inventory"] != validated["items"]:
		account["gold"] = gold
		account["inventory"] = validated["items"]
		revision += 1
	return _result(true)

func account_snapshot(account_id: String) -> Dictionary:
	return accounts.get(account_id, {}).duplicate(true)

# Empty owner = active public offers; a specified owner also sees their history.
func browse(owner_filter: String = "") -> Array:
	var result: Array = []
	for listing in listings.values():
		if owner_filter.is_empty() and listing["status"] != "active":
			continue
		if not owner_filter.is_empty() and listing["seller_id"] != owner_filter:
			continue
		var row: Dictionary = listing.duplicate(true)
		var seller: Dictionary = accounts.get(str(listing["seller_id"]), {})
		row["seller_name"] = str(seller.get("name", listing["seller_id"]))
		row["seller_kind"] = str(seller.get("kind", "player"))
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["serial"]) > int(b["serial"]))
	return result

func expire(now: int) -> int:
	if now < 0 or now > MAX_TIMESTAMP:
		return 0
	var count := 0
	for listing in listings.values():
		if listing["status"] != "active" or int(listing["expires_at"]) > now:
			continue
		var account: Dictionary = accounts[str(listing["seller_id"])]
		account["deliveries"].append(listing["item"].duplicate(true))
		listing["status"] = "expired"
		listing["closed_at"] = now
		count += 1
	if count > 0:
		revision += 1
	return count

func _receipt_key(actor_id: String, request_id: String) -> String:
	return JSON.stringify([actor_id, request_id]).sha256_text()

func _fingerprint(command: Dictionary) -> String:
	# Prices with NaN/Inf are rejected too, so receipt hashing must safely represent
	# malformed values without JSON warnings or collapsing NaN and null together.
	var parts: Array[String] = []
	for key in command:
		parts.append("%s:%s=%s:%s" % [typeof(key), var_to_str(key), typeof(command[key]), var_to_str(command[key])])
	parts.sort()
	return JSON.stringify(parts).sha256_text()

func _remember(actor_id: String, command: Dictionary, response: Dictionary) -> Dictionary:
	var request_id := str(command["request_id"])
	var request_seq := int(command.get("request_seq", 0))
	if request_seq > 0 and accounts.has(actor_id):
		accounts[actor_id]["last_request_seq"] = request_seq
		var ordered: Array = []
		for key in processed_commands:
			var receipt: Dictionary = processed_commands[key]
			if receipt["actor_id"] == actor_id and int(receipt.get("request_seq", 0)) > 0:
				ordered.append({"key": key, "seq": int(receipt["request_seq"])})
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["seq"] < b["seq"])
		while ordered.size() >= SEQUENCED_RECEIPTS_PER_ACCOUNT:
			processed_commands.erase(ordered.pop_front()["key"])
	if processed_commands.size() >= RECEIPT_CAP:
		# Close the old random-ID protocol permanently before pruning it. New
		# sequence IDs can then drain escrow/settlements at bounded storage cost.
		legacy_requests_closed = true
		processed_commands.erase(processed_commands.keys()[0])
	var saved := response.duplicate(true)
	saved["revision"] = revision
	saved["request_id"] = request_id
	if request_seq > 0:
		saved["request_seq"] = request_seq
	processed_commands[_receipt_key(actor_id, request_id)] = {"actor_id": actor_id, "request_id": request_id, "request_seq": request_seq, "fingerprint": _fingerprint(command), "response": saved.duplicate(true)}
	return saved

func submit(actor_id: String, command: Dictionary, now: int) -> Dictionary:
	if not _identifier(command.get("request_id")) or not _identifier(actor_id):
		return _result(false, "요청 ID 또는 계정 ID 오류")
	var sequenced := command.has("request_seq")
	if sequenced:
		if not _integer(command["request_seq"], 1, MAX_CURRENCY) or command["request_id"] != "seq_%d" % int(command["request_seq"]):
			return _result(false, "순차 요청 ID 오류")
	elif command["request_id"].begins_with("seq_"):
		return _result(false, "순차 요청에는 요청 번호가 필요합니다")
	var receipt_key := _receipt_key(actor_id, command["request_id"])
	if processed_commands.has(receipt_key):
		var receipt: Dictionary = processed_commands[receipt_key]
		if receipt["fingerprint"] != _fingerprint(command):
			return _result(false, "요청 ID를 다른 거래에 재사용할 수 없습니다")
		var duplicate: Dictionary = receipt["response"].duplicate(true)
		duplicate["duplicate"] = true
		return duplicate
	if not sequenced and (legacy_requests_closed or processed_commands.size() >= RECEIPT_CAP):
		return _result(false, "순차 요청 번호로 거래를 다시 진행해 주세요")
	if not accounts.has(actor_id):
		return _result(false, "등록되지 않은 계정")
	if sequenced and int(command["request_seq"]) <= int(accounts[actor_id]["last_request_seq"]):
		return _result(false, "이미 처리된 이전 거래 요청입니다")
	if now < 0 or now > MAX_TIMESTAMP - LISTING_DURATION:
		return _remember(actor_id, command, _result(false, "잘못된 거래 시간"))
	expire(now)
	if command.has("expected_revision") and (not _integer(command["expected_revision"], 0, MAX_CURRENCY) or int(command["expected_revision"]) != revision):
		return _remember(actor_id, command, _result(false, "거래소 정보가 변경되었습니다. 새로고침해 주세요"))
	var response: Dictionary
	match command.get("action", ""):
		"list": response = _list(actor_id, command, now)
		"buy": response = _buy(actor_id, command, now)
		"cancel": response = _cancel(actor_id, command, now)
		"claim": response = _claim(actor_id, command)
		_: response = _result(false, "지원하지 않는 거래 요청")
	return _remember(actor_id, command, response)

func _find_item(items: Array, item_id: String) -> int:
	for index in items.size():
		if str(items[index].get("id", "")) == item_id:
			return index
	return -1

func _prune_history() -> void:
	if listings.size() < HISTORY_CAP:
		return
	var oldest_key := ""
	var oldest_serial := MAX_CURRENCY
	for key in listings:
		var listing: Dictionary = listings[key]
		if listing["status"] != "active" and int(listing["serial"]) < oldest_serial:
			oldest_key = str(key)
			oldest_serial = int(listing["serial"])
	if not oldest_key.is_empty():
		listings.erase(oldest_key)

func _list(actor_id: String, command: Dictionary, now: int) -> Dictionary:
	if not _integer(command.get("price"), MIN_PRICE, MAX_PRICE) or not _identifier(command.get("item_id")):
		return _result(false, "판매가는 10~1,000,000,000 골드의 정수여야 합니다")
	var account: Dictionary = accounts[actor_id]
	var count := 0
	for listing in listings.values():
		if listing["seller_id"] == actor_id and listing["status"] == "active":
			count += 1
	if count >= LISTING_CAP:
		return _result(false, "동시 판매 등록은 5개까지 가능합니다")
	if account["deliveries"].size() >= DELIVERY_CAP - LISTING_CAP:
		return _result(false, "배송 보관함에서 장비를 먼저 받아 주세요")
	var index := _find_item(account["inventory"], command["item_id"])
	if index < 0:
		return _result(false, "가방에 해당 장비가 없습니다")
	var item: Dictionary = account["inventory"][index]
	if not RULES.tradable(item):
		return _result(false, RULES.trade_block_reason(item))
	_prune_history()
	if listings.size() >= HISTORY_CAP or next_listing_serial >= MAX_CURRENCY:
		return _result(false, "거래소 등록 한도 초과")
	var listing_id := "local_listing_%d" % next_listing_serial
	while listings.has(listing_id):
		next_listing_serial += 1
		if next_listing_serial >= MAX_CURRENCY:
			return _result(false, "거래소 등록 한도 초과")
		listing_id = "local_listing_%d" % next_listing_serial
	listings[listing_id] = {"id": listing_id, "serial": next_listing_serial, "seller_id": actor_id, "item": item.duplicate(true), "price": int(command["price"]), "created_at": now, "expires_at": now + LISTING_DURATION, "status": "active", "buyer_id": "", "closed_at": 0}
	next_listing_serial += 1
	account["inventory"].remove_at(index)
	revision += 1
	var response := _result(true, "48시간 동안 판매 등록되었습니다")
	response["listing_id"] = listing_id
	return response

func _listing_error(command: Dictionary) -> String:
	if not _identifier(command.get("listing_id")) or not listings.has(command["listing_id"]):
		return "해당 매물이 없습니다"
	if listings[command["listing_id"]]["status"] != "active":
		return "이미 거래가 종료된 매물입니다"
	return ""

func _buy(actor_id: String, command: Dictionary, now: int) -> Dictionary:
	var error := _listing_error(command)
	if not error.is_empty():
		return _result(false, error)
	var listing: Dictionary = listings[command["listing_id"]]
	if listing["seller_id"] == actor_id:
		return _result(false, "자신의 매물은 구매할 수 없습니다")
	var buyer: Dictionary = accounts[actor_id]
	var seller: Dictionary = accounts[listing["seller_id"]]
	var price := int(listing["price"])
	@warning_ignore("integer_division")
	var fee := maxi(1, (price + 19) / 20)
	var proceeds := price - fee
	if int(buyer["gold"]) < price:
		return _result(false, "골드가 부족합니다")
	if buyer["deliveries"].size() >= DELIVERY_CAP - LISTING_CAP:
		return _result(false, "배송 보관함에서 장비를 먼저 받아 주세요")
	if int(seller["gold"]) + int(seller["pending_gold"]) > MAX_CURRENCY - proceeds:
		return _result(false, "판매자의 골드 보유 한도 초과")
	var item: Dictionary = listing["item"].duplicate(true)
	item["bound"] = true
	item["trade_count"] = 1
	if str(item.get("item_type", "equipment")) == "option_crystal":
		var stored_option: Dictionary = item.get("stored_option", {})
		if not stored_option.is_empty():
			stored_option["trade_count"] = 1
	else:
		# The trade history follows the actual option through extraction and
		# implantation, so a purchased item cannot be laundered into resalable gems.
		for affix in item.get("affixes", []):
			affix["trade_count"] = 1
	buyer["gold"] -= price
	buyer["deliveries"].append(item)
	seller["pending_gold"] += proceeds
	listing["status"] = "sold"
	listing["buyer_id"] = actor_id
	listing["closed_at"] = now
	revision += 1
	var response := _result(true, "구매 완료. 배송 보관함에서 장비를 받아 주세요")
	response.merge({"listing_id": listing["id"], "price": price, "fee": fee, "proceeds": proceeds})
	return response

func _cancel(actor_id: String, command: Dictionary, now: int) -> Dictionary:
	var error := _listing_error(command)
	if not error.is_empty():
		return _result(false, error)
	var listing: Dictionary = listings[command["listing_id"]]
	if listing["seller_id"] != actor_id:
		return _result(false, "자신의 매물만 취소할 수 있습니다")
	accounts[actor_id]["deliveries"].append(listing["item"].duplicate(true))
	listing["status"] = "cancelled"
	listing["closed_at"] = now
	revision += 1
	return _result(true, "등록 취소. 배송 보관함으로 장비를 돌려보냈습니다")

func _claim(actor_id: String, command: Dictionary) -> Dictionary:
	if command.has("gold_only") and typeof(command["gold_only"]) != TYPE_BOOL:
		return _result(false, "잘못된 수령 요청")
	if command.has("item_id") and not _identifier(command["item_id"]):
		return _result(false, "잘못된 장비 ID")
	var account: Dictionary = accounts[actor_id]
	var claimed_items := 0
	var claimed_gold := int(account["pending_gold"])
	if int(account["gold"]) > MAX_CURRENCY - claimed_gold:
		return _result(false, "골드 보유 한도 초과")
	var requested_id := str(command.get("item_id", ""))
	if not bool(command.get("gold_only", false)):
		if not requested_id.is_empty() and _find_item(account["deliveries"], requested_id) < 0:
			return _result(false, "받을 장비가 없습니다")
		var index := 0
		while index < account["deliveries"].size() and account["inventory"].size() < INVENTORY_CAP:
			var item: Dictionary = account["deliveries"][index]
			if not requested_id.is_empty() and item["id"] != requested_id:
				index += 1
				continue
			account["inventory"].append(item)
			account["deliveries"].remove_at(index)
			claimed_items += 1
			if not requested_id.is_empty():
				break
	if claimed_items == 0 and claimed_gold == 0:
		return _result(false, "가방 공간이 부족합니다. 배송 장비는 보관됩니다" if not account["deliveries"].is_empty() and not bool(command.get("gold_only", false)) else "받을 정산금이나 장비가 없습니다")
	account["gold"] += claimed_gold
	account["pending_gold"] = 0
	revision += 1
	var response := _result(true, "정산금 %d 골드 · 장비 %d개 수령" % [claimed_gold, claimed_items])
	response.merge({"claimed_gold": claimed_gold, "claimed_items": claimed_items, "remaining_deliveries": account["deliveries"].size()})
	return response

func to_dict() -> Dictionary:
	return {"market_version": VERSION, "accounts": accounts.duplicate(true), "listings": listings.duplicate(true), "revision": revision, "next_listing_serial": next_listing_serial, "processed_commands": processed_commands.duplicate(true), "legacy_requests_closed": legacy_requests_closed}

# Recover valid ownership records conservatively. Active escrow/deliveries take
# precedence over stale account-inventory mirrors, and archive copies do not own
# items. Callers must also de-duplicate their equipped/overflow inventories.
func from_dict(raw: Dictionary, external_owned_ids: Array = []) -> void:
	accounts.clear()
	listings.clear()
	processed_commands.clear()
	legacy_requests_closed = typeof(raw.get("legacy_requests_closed")) == TYPE_BOOL and raw["legacy_requests_closed"]
	revision = 0
	next_listing_serial = 1
	load_warning = ""
	if raw.is_empty():
		return
	if not _integer(raw.get("market_version"), 1, VERSION):
		load_warning = "지원하지 않는 거래소 저장 버전"
		return
	revision = int(raw["revision"]) if _integer(raw.get("revision"), 0, MAX_CURRENCY) else 0
	next_listing_serial = int(raw["next_listing_serial"]) if _integer(raw.get("next_listing_serial"), 1, MAX_CURRENCY) else 1
	var raw_accounts: Dictionary = raw.get("accounts", {}) if typeof(raw.get("accounts")) == TYPE_DICTIONARY else {}
	for account_id in raw_accounts:
		if accounts.size() >= ACCOUNT_CAP:
			break
		if not _identifier(account_id) or typeof(raw_accounts[account_id]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_accounts[account_id]
		var gold := int(entry["gold"]) if _integer(entry.get("gold"), 0, MAX_CURRENCY) else 0
		var pending := int(entry["pending_gold"]) if _integer(entry.get("pending_gold"), 0, MAX_CURRENCY - gold) else 0
		accounts[account_id] = {"id": account_id, "name": entry.get("name", account_id).left(40) if typeof(entry.get("name", account_id)) == TYPE_STRING else str(account_id).left(40), "kind": "npc" if entry.get("kind") == "npc" else "player", "gold": gold, "pending_gold": pending, "inventory": [], "deliveries": [], "last_request_seq": int(entry["last_request_seq"]) if _integer(entry.get("last_request_seq"), 0, MAX_CURRENCY) else 0}
	var owned := {}
	for item_id in external_owned_ids:
		if _identifier(item_id):
			owned[item_id] = "external"
	var active_counts := {}
	var raw_listings: Dictionary = raw.get("listings", {}) if typeof(raw.get("listings")) == TYPE_DICTIONARY else {}
	for listing_id in raw_listings:
		if listings.size() >= HISTORY_CAP:
			break
		if not _identifier(listing_id) or typeof(raw_listings[listing_id]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_listings[listing_id]
		var seller_id: String = entry.get("seller_id", "") if typeof(entry.get("seller_id")) == TYPE_STRING else ""
		var item := _item(entry.get("item"))
		if not accounts.has(seller_id) or item.is_empty() or not _integer(entry.get("price"), MIN_PRICE, MAX_PRICE) or not _integer(entry.get("serial"), 1, MAX_CURRENCY - 1):
			continue
		if entry.get("status") not in ["active", "sold", "cancelled", "expired"] or not _integer(entry.get("created_at"), 0, MAX_TIMESTAMP) or not _integer(entry.get("expires_at"), 0, MAX_TIMESTAMP):
			continue
		if int(entry["expires_at"]) != int(entry["created_at"]) + LISTING_DURATION:
			continue
		var status := str(entry["status"])
		if status == "active" and owned.get(item["id"], "") == "external":
			status = "cancelled"
		if status == "active":
			if owned.has(item["id"]):
				continue
			owned[item["id"]] = true
			if not RULES.tradable(item) or int(active_counts.get(seller_id, 0)) >= LISTING_CAP:
				# A malformed sale cannot bypass the gear's binding/lock rules.
				# Preserve its uniquely owned equipment as a return delivery.
				status = "cancelled"
				if accounts[seller_id]["deliveries"].size() >= DELIVERY_CAP:
					continue
				accounts[seller_id]["deliveries"].append(item.duplicate(true))
			else:
				active_counts[seller_id] = int(active_counts.get(seller_id, 0)) + 1
		var buyer_id: String = entry.get("buyer_id", "") if typeof(entry.get("buyer_id")) == TYPE_STRING else ""
		var listing := {"id": str(listing_id), "serial": int(entry["serial"]), "seller_id": seller_id, "item": item, "price": int(entry["price"]), "created_at": int(entry["created_at"]), "expires_at": int(entry["expires_at"]), "status": status, "buyer_id": buyer_id if accounts.has(buyer_id) else "", "closed_at": int(entry["closed_at"]) if _integer(entry.get("closed_at"), 0, MAX_TIMESTAMP) else 0}
		listings[listing_id] = listing
		next_listing_serial = maxi(next_listing_serial, int(listing["serial"]) + 1)
	for field in ["deliveries", "inventory"]:
		for account_id in accounts:
			var raw_items = raw_accounts[account_id].get(field, [])
			if typeof(raw_items) != TYPE_ARRAY:
				continue
			var maximum := DELIVERY_CAP if field == "deliveries" else INVENTORY_CAP
			for value in raw_items:
				if accounts[account_id][field].size() >= maximum:
					break
				var item := _item(value)
				if item.is_empty():
					continue
				var local_mirror: bool = field == "inventory" and account_id == "player_local" and owned.get(item["id"], "") == "external"
				if owned.has(item["id"]) and not local_mirror:
					continue
				owned[item["id"]] = true
				accounts[account_id][field].append(item)
	var raw_receipts: Dictionary = raw.get("processed_commands", {}) if typeof(raw.get("processed_commands")) == TYPE_DICTIONARY else {}
	if raw_receipts.size() > RECEIPT_CAP:
		legacy_requests_closed = true
	for key in raw_receipts:
		if processed_commands.size() >= RECEIPT_CAP:
			break
		if typeof(raw_receipts[key]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_receipts[key]
		if not _identifier(entry.get("actor_id")) or not _identifier(entry.get("request_id")) or typeof(entry.get("fingerprint")) != TYPE_STRING or entry["fingerprint"].length() != 64 or typeof(entry.get("response")) != TYPE_DICTIONARY:
			continue
		var response: Dictionary = entry["response"]
		if typeof(response.get("ok")) != TYPE_BOOL or typeof(response.get("reason")) != TYPE_STRING or not _integer(response.get("revision"), 0, MAX_CURRENCY):
			continue
		var clean_response := {"ok": response["ok"], "reason": response["reason"].left(200), "revision": int(response["revision"]), "request_id": entry["request_id"]}
		var request_seq := int(entry["request_seq"]) if _integer(entry.get("request_seq"), 1, MAX_CURRENCY) else 0
		if request_seq > 0:
			if not accounts.has(entry["actor_id"]) or entry["request_id"] != "seq_%d" % request_seq:
				continue
			clean_response["request_seq"] = request_seq
			accounts[entry["actor_id"]]["last_request_seq"] = maxi(int(accounts[entry["actor_id"]]["last_request_seq"]), request_seq)
		for field in ["listing_id"]:
			if _identifier(response.get(field)):
				clean_response[field] = response[field]
		for field in ["price", "fee", "proceeds", "claimed_gold", "claimed_items", "remaining_deliveries"]:
			if _integer(response.get(field), 0, MAX_CURRENCY):
				clean_response[field] = int(response[field])
		var receipt_key := _receipt_key(entry["actor_id"], entry["request_id"])
		processed_commands[receipt_key] = {"actor_id": entry["actor_id"], "request_id": entry["request_id"], "request_seq": request_seq, "fingerprint": entry["fingerprint"], "response": clean_response}
