import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import TerritoriesBoard from "@/components/territories-board";
export const dynamic="force-dynamic";
export default async function TerritoriesPage(){
 const supabase=await createClient();if(!supabase)redirect("/login");const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:territoryRows}=await supabase.from("agbero_territories").select("id,name,description,stamp_duty_ac,owner_id,owner:profiles!agbero_territories_owner_id_fkey(username,display_name)").eq("active",true).order("created_at",{ascending:true});
 const {data:membershipRow}=await supabase.from("agbero_memberships").select("id,territory_id,citizen_id,duty_due_ac,duty_paid_ac,entered_at,noncash_obligation,noncash_completed").eq("citizen_id",user.id).eq("status","inside").maybeSingle();
 const {data:ownedRows}=await supabase.from("agbero_territories").select("id,name,description,stamp_duty_ac,owner_id").eq("owner_id",user.id).eq("active",true);
 const ownerIds=(ownedRows??[]).map(t=>t.id);
 const {data:memberRows}=ownerIds.length?await supabase.from("agbero_memberships").select("id,territory_id,citizen_id,duty_due_ac,duty_paid_ac,entered_at,noncash_obligation,noncash_completed").in("territory_id",ownerIds).eq("status","inside"): {data:[] as {id:string;territory_id:string;citizen_id:string;duty_due_ac:number;duty_paid_ac:number;entered_at:string;noncash_obligation:string|null;noncash_completed:boolean}[]};
 const ids=Array.from(new Set((memberRows??[]).map(m=>m.citizen_id)));
 const {data:profiles}=ids.length?await supabase.from("profiles").select("id,username,display_name").in("id",ids):{data:[] as {id:string;username:string;display_name:string|null}[]};
 const profileMap=new Map((profiles??[]).map(p=>[p.id,p]));
 const territories=(territoryRows??[]).map(t=>({...t,owner:Array.isArray(t.owner)?t.owner[0]??null:t.owner}));
 const membership=membershipRow?{...membershipRow,territory_name:territories.find(t=>t.id===membershipRow.territory_id)?.name??"this territory"}:null;
 const ownedMembers=(memberRows??[]).map(m=>({...m,territory_name:ownedRows?.find(t=>t.id===m.territory_id)?.name??"Territory",username:profileMap.get(m.citizen_id)?.username??"unknown",display_name:profileMap.get(m.citizen_id)?.display_name??"Citizen"}));
 return <main className="shell territory-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/">The street ↗</Link><Link href="/wallet">AC wallet</Link><Link href="/account">My account</Link></div></header>
 <section className="territory-masthead"><span className="eyebrow">AREA / TERRITORIES</span><h1>Every ground<br/>has its <em>Agbero.</em></h1><p>Stamp duty, territory obligations and the people who can set you free. One shared society; many corners of influence.</p></section>
 <div className="section-rule"><span>AGBERO TERRITORIES</span><span>ENTRY IS NOT AN EXIT</span></div>
 <TerritoriesBoard territories={territories} membership={membership} ownedTerritories={(ownedRows??[]).map(t=>({...t,owner:null}))} ownedMembers={ownedMembers}/>
 <footer className="site-footer"><span>AREA / TERRITORIES</span><span>Owner-controlled release</span><Link href="/">Back to the street ↗</Link></footer></main>;
}