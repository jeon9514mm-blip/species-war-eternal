extends RefCounted
## Authored identities, not elemental damage rules. One shader program and one
## glyph atlas serve 120 distinct hero/slot materials without 120 shader builds.
const ROSTER=preload('res://scripts/heroes/HeroRosterCatalog.gd')
const THEMES={
	'leonhardt':['bastion','#EBC878','#F9F2D7',6], 'mira':['reticle','#79CBE8','#DAF6FF',4],
	'elisia':['worldtree','#91D291','#E7F8B4',7], 'kairen':['orrery','#8CABF8','#E2E8FF',8],
	'orwin':['phalanx','#DDB875','#FFF1CA',6], 'seria':['sixfeathers','#87E3D4','#F3FFFB',6],
	'astel':['dawnchoir','#F2D5AA','#FFEDF1',8], 'darius':['judgement','#F1AB78','#FFF0D7',4],
	'lunea':['mistmaze','#93BCCB','#DCEDFA',7], 'caelum':['sunwheel','#F7B454','#FFF1A7',12],
	'valeria':['bloodmoon','#E66A8B','#FFE0CD',6], 'morgas':['alchemy','#AD81D4','#E9CDF4',7],
	'ragna':['wolfmoon','#9BA5F2','#DEE7FF',5], 'bron':['mountain','#C9AC80','#EEE2C0',6],
	'nyx':['seveneyes','#B78BE7','#F1D9FF',7], 'fenris':['frostclaws','#A6D9E7','#EEFAFF',6],
	'isolde':['bloodrose','#EC93AB','#FFE4D5',8], 'garm':['ironfang','#C89978','#F9E2BF',5],
	'veyra':['nightdance','#BA7AE0','#F0BDE4',9], 'ulric':['eclipse','#9D9BCB','#E7D4EE',6],
	'adrien':['duelcrest','#A9CDE7','#F0F9FE',4], 'tessa':['runecannon','#E3AE76','#FFF0C6',8],
	'naia':['supernova','#B3B8F7','#F6EBFF',9], 'sael':['thousandleaves','#8DCBB3','#DEF6BB',10],
	'odelia':['royalseal','#C29BCA','#F4DEFC',8], 'lucien':['oathspear','#D97E88','#FCE2CC',5],
	'corvin':['twilightchoir','#A596CC','#F0DDFB',7], 'rokan':['huntingfang','#B9CEE0','#F4F4DD',3],
	'bora':['snowfist','#AADCE5','#F6FEFF',6], 'selene':['redthreads','#ECA8AE','#FFE1D8',8]}
const SLOT_ORDER=['passive','a1','a2','ultimate']
static func profile(hero_id: String,slot: String) -> Dictionary:
	if not THEMES.has(hero_id) or not SLOT_ORDER.has(slot):return {}
	var hero_index: int=THEMES.keys().find(hero_id)
	var slot_index: int=SLOT_ORDER.find(slot)
	var kit: Dictionary=ROSTER.skill(hero_id,slot)
	var theme: Array=THEMES[hero_id]
	var passive: bool=slot=='passive';var ultimate: bool=slot=='ultimate'
	return {'hero_id':hero_id,'slot':slot,'skill':str(kit.get('skill','')),
		'signature':hero_id+':'+slot,'motif':theme[0],'color':Color(theme[1]),'core':Color(theme[2]),
		'kind':str(kit.get('kind','damage')),'glyph':hero_index,'seed':float(hero_index*4+slot_index+1),
		'symmetry':int(theme[3])+slot_index,'charge':.08 if passive else (.22 if ultimate else .10),
		'flight':.12 if passive else (.26 if ultimate else .18),'impact':.20 if passive else (.47 if ultimate else .27),
		'tail':.40,'particles':40,'sub_particles':20,'echoes':5,'trail':.40,
		'power':.65 if passive else (1.8 if ultimate else 1.2),
		'twist':float(hero_index%7-3)*.15+float(slot_index)*.11,'ultimate':ultimate,'passive':passive}
