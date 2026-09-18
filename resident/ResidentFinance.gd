class_name ResidentFinance
extends RefCounted

const STARTING_CASH:=12000
const GROCERIES_COST:=1200
const WORK_INCOME:=3000
const FIXED_EXPENSE:=900
const FIXED_INTERVAL_MINUTES:=1440.0
var cash:=STARTING_CASH
var total_income:=0
var total_expenses:=0
var next_fixed_expense_time:=1440.0
var expense_history:Array=[]
var income_history:Array=[]

func can_afford(amount:int)->bool:return amount>=0 and cash>=amount
func spend(amount:int,reason:String,time_text:String)->bool:
	if not can_afford(amount):
		return false
	cash-=amount
	total_expenses+=amount
	expense_history.push_front({"amount":amount,"reason":reason,"time":time_text})
	if expense_history.size()>30:expense_history.resize(30)
	return true
func earn(amount:int,reason:String,time_text:String)->void:
	if amount<=0:return
	cash+=amount;total_income+=amount;income_history.push_front({"amount":amount,"reason":reason,"time":time_text});if income_history.size()>30:income_history.resize(30)
func advance(total_minutes:float,time_text:String)->Array:
	var events:Array=[]
	while total_minutes>=next_fixed_expense_time:
		var charged:int=min(cash,FIXED_EXPENSE);spend(charged,"fixed_living_cost",time_text);events.append({"due":FIXED_EXPENSE,"paid":charged});next_fixed_expense_time+=FIXED_INTERVAL_MINUTES
	return events
func snapshot(total_minutes:float)->Dictionary:
	return {"cash":cash,"total_income":total_income,"total_expenses":total_expenses,"next_fixed_expense":{"amount":FIXED_EXPENSE,"due_in_hours":max(0.0,next_fixed_expense_time-total_minutes)/60.0},"recent_income":int(income_history[0].amount) if not income_history.is_empty() else 0,"recent_expense":int(expense_history[0].amount) if not expense_history.is_empty() else 0}
func serialize()->Dictionary:return {"cash":cash,"total_income":total_income,"total_expenses":total_expenses,"next_fixed_expense_time":next_fixed_expense_time,"expense_history":expense_history,"income_history":income_history}
func load_state(data)->void:
	if not data is Dictionary:return
	cash=max(0,int(data.get("cash",STARTING_CASH)));total_income=max(0,int(data.get("total_income",0)));total_expenses=max(0,int(data.get("total_expenses",0)));next_fixed_expense_time=float(data.get("next_fixed_expense_time",1440.0));expense_history=data.get("expense_history",[]) if data.get("expense_history",[]) is Array else [];income_history=data.get("income_history",[]) if data.get("income_history",[]) is Array else []
