class_name RelationshipStore
extends RefCounted

const PAID_COST:=12000
var contacts:Dictionary={
	"girlfriend_01":{"id":"girlfriend_01","display_name":"恋人","relation_type":"girlfriend","adult":true,"relationship":72,"trust":80,"attraction":75,"intimacy_interest":70,"availability":true,"recent_contact_time":"","last_interaction":"","flags":[]},
	"friend_01":{"id":"friend_01","display_name":"友人","relation_type":"friend","adult":true,"relationship":60,"trust":65,"attraction":30,"intimacy_interest":20,"availability":true,"recent_contact_time":"","last_interaction":"","flags":[]},
	"ex_01":{"id":"ex_01","display_name":"元恋人","relation_type":"ex","adult":true,"relationship":42,"trust":35,"attraction":58,"intimacy_interest":45,"availability":false,"recent_contact_time":"","last_interaction":"","flags":[]},
	"dating_match_01":{"id":"dating_match_01","display_name":"マッチした相手","relation_type":"dating_match","adult":true,"relationship":20,"trust":25,"attraction":65,"intimacy_interest":50,"availability":true,"recent_contact_time":"","last_interaction":"","flags":[]},
	"casual_partner_01":{"id":"casual_partner_01","display_name":"親しい相手","relation_type":"casual_partner","adult":true,"relationship":32,"trust":45,"attraction":70,"intimacy_interest":72,"availability":true,"recent_contact_time":"","last_interaction":"","flags":[]},
	"sex_worker_01":{"id":"sex_worker_01","display_name":"有料サービス","relation_type":"sex_worker","adult":true,"relationship":0,"trust":50,"attraction":50,"intimacy_interest":100,"availability":true,"recent_contact_time":"","last_interaction":"","flags":[]},
	"family_member_01":{"id":"family_member_01","display_name":"家族","relation_type":"family","adult":true,"relationship":70,"trust":75,"attraction":0,"intimacy_interest":0,"availability":true,"recent_contact_time":"","last_interaction":"","flags":[]}
}
var accepted_partner_context:Dictionary={}

func sex_partner_candidates(cash:int)->Array:
	var result:Array=[]
	for id in contacts:
		var c:Dictionary=contacts[id]
		if not bool(c.availability) or not bool(c.get("adult",false)) or str(c.relation_type)=="family":continue
		if str(c.relation_type)=="sex_worker" and cash<PAID_COST:continue
		if str(c.relation_type)=="friend" and (int(c.attraction)<50 or int(c.intimacy_interest)<45):continue
		if str(c.relation_type)=="girlfriend" and (int(c.relationship)<45 or int(c.trust)<45 or int(c.intimacy_interest)<40):continue
		if str(c.relation_type)=="ex" and (int(c.trust)<30 or int(c.intimacy_interest)<40):continue
		if str(c.relation_type)=="dating_match" and int(c.intimacy_interest)<45:continue
		if str(c.relation_type)=="casual_partner" and int(c.intimacy_interest)<60:continue
		result.append(id)
	return result
func invite(contact_id:String,cash:int,time_text:String)->Dictionary:
	if not contacts.has(contact_id):return {"ok":false,"outcome":"invalid_partner"}
	var c:Dictionary=contacts[contact_id]
	if not bool(c.availability):return {"ok":false,"outcome":"unavailable"}
	if not bool(c.get("adult",false)) or str(c.relation_type)=="family":return {"ok":false,"outcome":"invalid_partner"}
	if str(c.relation_type)=="sex_worker" and cash<PAID_COST:return {"ok":false,"outcome":"cannot_afford"}
	var eligible:=contact_id in sex_partner_candidates(cash)
	var score:=int(c.relationship)+int(c.trust)+int(c.attraction)+int(c.intimacy_interest)
	var accepted:=eligible and (score+contact_id.length()*7)%100>=35
	c.last_interaction="sexual_invitation";c.recent_contact_time=time_text
	if accepted:accepted_partner_context={"contact_id":contact_id,"accepted_at":time_text,"relation_type":c.relation_type};return {"ok":true,"outcome":"accepted","contact_id":contact_id}
	c.relationship=max(0,int(c.relationship)-2);c.trust=max(0,int(c.trust)-3);return {"ok":false,"outcome":"declined","contact_id":contact_id}
func consume_context(contact_id:String)->Dictionary:
	if str(accepted_partner_context.get("contact_id",""))!=contact_id:return {"ok":false,"outcome":"accepted_context_required"}
	var result:=accepted_partner_context.duplicate(true);accepted_partner_context={};return {"ok":true,"context":result}
func contact(contact_id:String,kind:String,time_text:String)->Dictionary:
	if not contacts.has(contact_id):return {"ok":false,"outcome":"invalid_contact"}
	var c:Dictionary=contacts[contact_id];if not bool(c.availability):return {"ok":false,"outcome":"unavailable"}
	c.relationship=clamp(int(c.relationship)+2,0,100);c.trust=clamp(int(c.trust)+1,0,100);c.last_interaction=kind;c.recent_contact_time=time_text;return {"ok":true,"outcome":"pleasant_contact","contact_id":contact_id}
func observation()->Dictionary:
	var out:Dictionary={};for id in contacts:var c:Dictionary=contacts[id];out[id]={"type":c.relation_type,"relationship":c.relationship,"trust":c.trust,"available":c.availability}
	return out
func serialize()->Dictionary:return {"contacts":contacts,"accepted_partner_context":accepted_partner_context}
func load_state(data)->void:
	if not data is Dictionary:return
	var saved_contacts=data.get("contacts",{})
	if saved_contacts is Dictionary:
		for id in saved_contacts:
			if contacts.has(id) and saved_contacts[id] is Dictionary:contacts[id].merge(saved_contacts[id],true)
	accepted_partner_context=data.get("accepted_partner_context",{}) if data.get("accepted_partner_context",{}) is Dictionary else {}
