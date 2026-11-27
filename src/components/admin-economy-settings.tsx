"use client";
import { useEffect,useState } from "react";
import { createClient } from "@/lib/supabase/client";
const fields=[
 {key:"gbas_gbos_level_2_cost_ac",label:"Gbas Gbos / Heated escalation",suffix:"AC"},
 {key:"gbas_gbos_level_3_cost_ac",label:"Gbas Gbos / Full Wahala escalation",suffix:"AC"},
 {key:"ac_per_ngn",label:"AC per ₦1",suffix:"AC"},
 {key:"agbero_default_stamp_duty_ac",label:"Default Agbero stamp duty",suffix:"AC"},
 {key:"agbero_area_share_percent",label:"AREA share of Agbero duty",suffix:"%"},
 {key:"community_penance_area_share_percent",label:"AREA share of community penance",suffix:"%"}
] as const;
type Key=typeof fields[number]["key"];
export default function AdminEconomySettings(){
 const [values,setValues]=useState<Record<Key,string>>({gbas_gbos_level_2_cost_ac:"0",gbas_gbos_level_3_cost_ac:"0",ac_per_ngn:"0",agbero_default_stamp_duty_ac:"0",agbero_area_share_percent:"30",community_penance_area_share_percent:"30"});
 const [busy,setBusy]=useState<Key|null>(null),[saved,setSaved]=useState<Key|null>(null),[error,setError]=useState("");
 useEffect(()=>{let live=true;void createClient().from("area_economy_settings").select("setting_key,setting_value").then(({data})=>{if(!live)return;const next:Record<Key,string>={gbas_gbos_level_2_cost_ac:"0",gbas_gbos_level_3_cost_ac:"0",ac_per_ngn:"0",agbero_default_stamp_duty_ac:"0",agbero_area_share_percent:"30",community_penance_area_share_percent:"30"};for(const row of data??[]){if(row.setting_key in next)next[row.setting_key as Key]=String(row.setting_value);}setValues(next);});return()=>{live=false;};},[]);
 async function save(key:Key){setBusy(key);setError("");setSaved(null);try{const value=Number(values[key]);if(!Number.isSafeInteger(value)||value<0)throw new Error("Enter a whole, non-negative number.");const {error}=await createClient().rpc("admin_update_area_economy_setting",{p_key:key,p_value:value});if(error)throw error;setSaved(key);}catch(e){setError(e instanceof Error?e.message:"Could not save this setting.");}finally{setBusy(null);}}
 return <section className="admin-economy-settings"><div className="admin-panel-head"><div><span className="mini-label">ECONOMY RULES</span><h2>Set the prices and splits</h2></div><span>OWNER CONFIGURATION</span></div><div className="admin-economy-grid">{fields.map(field=><div className="admin-economy-field" key={field.key}><label>{field.label}</label><div><input inputMode="numeric" value={values[field.key]} onChange={e=>setValues(v=>({...v,[field.key]:e.target.value.replace(/[^0-9]/g,"")}))}/><span>{field.suffix}</span><button disabled={busy===field.key} onClick={()=>void save(field.key)}>{busy===field.key?"Saving…":saved===field.key?"Saved ✓":"Save"}</button></div></div>)}</div><p>Zero means not configured. Paid escalation remains free until you set its AC price. The AC/naira conversion is not applied to payments until the rate and payment provider are finalised.</p>{error&&<small className="error">{error}</small>}</section>;
}