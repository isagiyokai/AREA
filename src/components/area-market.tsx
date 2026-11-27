"use client";
import Link from "next/link";
import { useEffect,useState } from "react";
import { createClient } from "@/lib/supabase/client";
type Item={id:string;slug:string;name:string;description:string;category:string;price_ac:number};
type Owned={item_id:string;equipped:boolean};
const fmt=(n:number)=>new Intl.NumberFormat("en-NG").format(n);
const categoryLabel:Record<string,string>={profile_frame:"PROFILE FRAME",profile_stamp:"STREET STAMP",nameplate:"NAMEPLATE",profile_backdrop:"PROFILE BACKDROP"};
export default function AreaMarket({userId}:{userId:string|null}){
 const [items,setItems]=useState<Item[]>([]),[owned,setOwned]=useState<Owned[]>([]),[loading,setLoading]=useState(true),[acPerNgn,setAcPerNgn]=useState(0),[busy,setBusy]=useState<string|null>(null),[error,setError]=useState(""),[message,setMessage]=useState("");
 async function refresh(){const sb=createClient();const [{data:catalog,error:catalogError},{data:inventory},{data:rate}]=await Promise.all([
  sb.from("area_market_items").select("id,slug,name,description,category,price_ac").eq("active",true).order("price_ac",{ascending:true}),
  userId?sb.from("citizen_inventory").select("item_id,equipped").eq("user_id",userId):Promise.resolve({data:[] as Owned[],error:null}),
  sb.from("area_economy_settings").select("setting_value").eq("setting_key","ac_per_ngn").maybeSingle()
 ]);if(catalogError)throw catalogError;setItems((catalog??[]) as Item[]);setOwned((inventory??[]) as Owned[]);setAcPerNgn(Number(rate?.setting_value)||0);setLoading(false);}
 useEffect(()=>{void refresh().catch(e=>{setError(e instanceof Error?e.message:"Market unavailable.");setLoading(false);});},[userId]);
 async function buy(item:Item){if(!userId){window.location.href="/login";return;}setBusy(item.id);setError("");setMessage("");try{const {data,error}=await createClient().rpc("purchase_market_item",{p_item_id:item.id});if(error)throw error;const result=data as {item_name:string;amount_ac:number};setMessage(`${result.item_name} added to your inventory for ${fmt(result.amount_ac)} AC.`);await refresh();}catch(e){setError(e instanceof Error?e.message:"Purchase could not be completed.");}finally{setBusy(null);}}
 async function equip(item:Item){if(!userId)return;setBusy(item.id);setError("");setMessage("");try{const {error}=await createClient().rpc("equip_market_item",{p_item_id:item.id});if(error)throw error;setMessage(item.name+" equipped.");await refresh();}catch(e){setError(e instanceof Error?e.message:"Could not equip this item.");}finally{setBusy(null);}}
 return <div className="market-layout"><div className="market-intro-row"><p>Cosmetics and personal marks for your place in AREA. Items are owned permanently once purchased.</p><Link className="btn" href={userId?"/wallet":"/login"}>{userId?"Open AC wallet ↗":"Sign in to buy"}</Link></div>
 {message&&<p className="wallet-success">{message}</p>}{error&&<p className="error">{error}</p>}
 {loading?<p className="notice">Opening the market…</p>:!items.length?<p className="notice">The shelves are empty for now.</p>:<div className="market-grid">{items.map(item=>{const possession=owned.find(x=>x.item_id===item.id);return <article className={"market-item "+item.category} key={item.id}><div className="market-item-art"><span>{categoryLabel[item.category]||"AREA ITEM"}</span><strong>{item.name}</strong><b>AREA / GOODS</b></div><div className="market-item-copy"><span className="mini-label">{categoryLabel[item.category]||item.category}</span><h2>{item.name}</h2><p>{item.description}</p><div className="market-item-buy"><strong>{fmt(item.price_ac)} <small>AC</small>{acPerNgn>0&&<small className="market-naira-reference">≈ ₦{fmt(item.price_ac/acPerNgn)} reference</small>}</strong>{possession?<button className="btn" disabled={busy===item.id||possession.equipped} onClick={()=>void equip(item)}>{possession.equipped?"Equipped ✓":"Equip"}</button>:<button className="btn primary" disabled={busy===item.id||!userId} onClick={()=>void buy(item)}>{busy===item.id?"Processing…":"Buy item ↗"}</button>}</div></div></article>})}</div>}
 <p className="market-footnote">AC is internal AREA currency. Naira equivalents are reference values only; these purchases are not naira payments and cannot be cashed out. External payment rails are not active yet.</p></div>;
}