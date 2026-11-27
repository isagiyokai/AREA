"use client";
import { useEffect,useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
type Tier={tier_key:string;area_class:string;grade_title:string;price_ngn:number;starting_ac:number;privileges:Record<string,unknown>;starter_connections:string[];sort_order:number};
const fmt=(n:number)=>new Intl.NumberFormat("en-NG").format(n);
export default function EntryTierChooser(){
 const [tiers,setTiers]=useState<Tier[]>([]),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState("");
 const router=useRouter();
 useEffect(()=>{void createClient().from("area_entry_tiers").select("tier_key,area_class,grade_title,price_ngn,starting_ac,privileges,starter_connections,sort_order").eq("active",true).order("sort_order").then(({data,error})=>{if(error){setError(error.message);}else setTiers((data??[]) as Tier[]);setLoading(false);});},[]);
 async function chooseSlums(){setBusy(true);setError("");try{const {error}=await createClient().rpc("select_free_slums_entry");if(error)throw error;router.push("/");router.refresh();}catch(e){setError(e instanceof Error?e.message:"Could not complete your entry.");}finally{setBusy(false);}}
 return <div className="entry-tier-wrap"><div className="entry-tier-intro"><span className="mini-label">CHOOSE YOUR STARTING POSITION</span><p>Every citizen enters the same society, but not everyone starts with the same pocket, title or connections.</p></div>
 {error&&<p className="error">{error}</p>}{loading?<p className="notice">Loading entry tiers…</p>:<div className="entry-tier-grid">{tiers.map(tier=><article className={"entry-tier-card "+tier.area_class} key={tier.tier_key}><span className="mini-label">{tier.area_class.toUpperCase()} CLASS</span><h2>{tier.grade_title}</h2><div className="entry-tier-price">{tier.price_ngn===0?"FREE":"₦"+fmt(tier.price_ngn)}</div><p>{tier.area_class==="slums"?"Start with nothing but your name and the street.":tier.area_class==="lapo"?"Start with a little backing and a place to climb from.":"Enter with the strongest starting position."}</p>{tier.starter_connections.includes("nepo")&&<small className="entry-tier-connection">Nepo introduction included in tier design</small>}
 {tier.price_ngn===0?<button className="btn primary" disabled={busy} onClick={()=>void chooseSlums()}>{busy?"Entering…":"Start in Slums ↗"}</button>:<button className="btn" disabled>Paid checkout not enabled yet</button>}
 </article>)}</div>}
 <p className="entry-tier-footnote">Paid Lapo and Nepo entries are listed at their agreed naira prices, but checkout is deliberately disabled until payment verification is connected. AC starting balances and class privileges are not granted until that flow is finalised.</p></div>;
}