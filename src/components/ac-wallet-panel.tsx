"use client";
import { useEffect,useState } from "react";
import { createClient } from "@/lib/supabase/client";

type LedgerItem={id:string;amount_ac:number;transaction_type:string;note:string|null;created_at:string;direction:"in"|"out";counterparty:string};
type Wallet={balance_ac:number;history:LedgerItem[]};
type Package={package_key:string;name:string;amount_ngn:number;base_ac:number;bonus_ac:number;sort_order:number};
const fmt=(n:number)=>new Intl.NumberFormat("en-NG").format(n);
export default function AcWalletPanel({initialWallet,paymentsEnabled}:{initialWallet:Wallet|null;paymentsEnabled:boolean}){
 const [wallet,setWallet]=useState<Wallet|null>(initialWallet),[loading,setLoading]=useState(!initialWallet),[acPerNgn,setAcPerNgn]=useState(0),[packages,setPackages]=useState<Package[]>([]),[username,setUsername]=useState(""),[amount,setAmount]=useState(""),[note,setNote]=useState(""),[busy,setBusy]=useState(false),[topupBusy,setTopupBusy]=useState<string|null>(null),[message,setMessage]=useState(""),[error,setError]=useState("");
 async function refresh(){const sb=createClient();const {data,error}=await sb.rpc("get_my_ac_wallet");if(error)throw error;setWallet(data as Wallet);setLoading(false);}
 useEffect(()=>{
  const sb=createClient();
  void Promise.all([
   sb.from("area_economy_settings").select("setting_value").eq("setting_key","ac_per_ngn").maybeSingle(),
   sb.from("area_ac_packages").select("package_key,name,amount_ngn,base_ac,bonus_ac,sort_order").eq("active",true).order("sort_order")
  ]).then(([rateResult,packageResult])=>{
   setAcPerNgn(Number(rateResult.data?.setting_value)||0);
   if(!packageResult.error)setPackages((packageResult.data??[]) as Package[]);
  });
  const paymentStatus=new URLSearchParams(window.location.search).get("payment");
  if(paymentStatus==="success"){setMessage("Payment verified. Your AC has been credited.");void refresh().catch(e=>setError(e instanceof Error?e.message:"Wallet refresh failed."));}
  if(paymentStatus==="verify_failed")setError("AREA could not verify the payment yet. Do not pay again immediately; refresh your wallet or contact support if the debit remains.");
  if(!initialWallet)void refresh().catch(e=>{setError(e instanceof Error?e.message:"Wallet unavailable.");setLoading(false);});
 },[]);
 async function buy(packageKey:string){
  setTopupBusy(packageKey);setError("");setMessage("");
  try{
   const response=await fetch("/api/payments/paystack/initialize",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({package_key:packageKey})});
   const result=(await response.json()) as {authorization_url?:string;error?:string};
   if(!response.ok||!result.authorization_url)throw new Error(result.error||"Could not open checkout.");
   window.location.assign(result.authorization_url);
  }catch(e){setError(e instanceof Error?e.message:"Checkout could not be started.");setTopupBusy(null);}
 }
 async function send(){setBusy(true);setError("");setMessage("");try{const sb=createClient();const {data,error}=await sb.rpc("transfer_ac",{p_recipient_username:username.trim().replace(/^@/,""),p_amount:Number(amount),p_note:note.trim()||null});if(error)throw error;const result=data as {balance_ac:number;amount_ac:number;recipient_username:string};setMessage(`Sent ${fmt(result.amount_ac)} AC to @${result.recipient_username}.`);setUsername("");setAmount("");setNote("");await refresh();}catch(e){setError(e instanceof Error?e.message:"Transfer could not be completed.");}finally{setBusy(false);}}
 return <div className="wallet-layout">
  <section className="wallet-balance"><span className="mini-label">YOUR AVAILABLE BALANCE</span><div className="wallet-amount">{loading?"…":fmt(wallet?.balance_ac??0)} <small>AC</small></div><p>AREA currency · kept inside the society</p>{acPerNgn>0&&<small>≈ ₦{fmt((wallet?.balance_ac??0)/acPerNgn)} reference value · not cash value</small>}<div className="wallet-balance-foot"><span>NO CASH VALUE YET</span><span>WALLET / 001</span></div></section>
  <section className="wallet-topup"><div className="wallet-section-head"><div><span className="mini-label">ADD TO YOUR WALLET</span><h2>Buy AREA Credits</h2></div><span className="wallet-index">02 / TOP UP</span></div><p>One naira maps to 50 AC. Larger packages include a clearly listed bonus. No subscription and no automatic renewal.</p><div className="wallet-package-grid">{packages.map(item=><article className="wallet-package" key={item.package_key}><span className="mini-label">{item.name.toUpperCase()}</span><strong>₦{fmt(item.amount_ngn)}</strong><b>{fmt(item.base_ac+item.bonus_ac)} AC</b><small>{fmt(item.base_ac)} base AC{item.bonus_ac>0?` + ${fmt(item.bonus_ac)} bonus`:""}</small>{item.bonus_ac>0&&<small className="wallet-package-bonus">{Math.round(item.bonus_ac/item.base_ac*100)}% package bonus</small>}<button className="btn primary" disabled={!paymentsEnabled||topupBusy!==null} onClick={()=>void buy(item.package_key)}>{topupBusy===item.package_key?"Opening…":paymentsEnabled?"Buy AC ↗":"Checkout not connected"}</button></article>)}</div>{!paymentsEnabled&&<small className="wallet-payment-note">Payment checkout is built but not activated. It will open after the server payment keys and webhook are configured.</small>}</section>
  <section className="wallet-transfer"><div className="wallet-section-head"><div><span className="mini-label">MOVE AC</span><h2>Send a citizen a gift</h2></div><span className="wallet-index">03 / TRANSFER</span></div>
   <label>Citizen username<input value={username} onChange={e=>setUsername(e.target.value)} placeholder="@username" maxLength={25}/></label>
   <label>Amount in AC<input value={amount} onChange={e=>setAmount(e.target.value.replace(/[^0-9]/g,""))} inputMode="numeric" placeholder="e.g. 25000"/></label>{acPerNgn>0&&Number(amount)>0&&<small>≈ ₦{fmt(Number(amount)/acPerNgn)} reference value</small>}
   <label>Note <span className="wallet-optional">OPTIONAL</span><input value={note} onChange={e=>setNote(e.target.value)} placeholder="What's it for?" maxLength={120}/></label>
   <button className="btn primary" disabled={busy||!username.trim()||!amount||Number(amount)<1} onClick={()=>void send()}>{busy?"Sending…":"Send AC ↗"}</button>
   {message&&<p className="wallet-success">{message}</p>}{error&&<p className="error">{error}</p>}
  </section>
  <section className="wallet-history"><div className="wallet-section-head"><div><span className="mini-label">MONEY MOVES</span><h2>Recent transactions</h2></div><span className="wallet-index">LAST 40</span></div>
   {!wallet?.history?.length?<p className="notice">Nothing has moved yet. Your AC activity will appear here.</p>:<div className="wallet-ledger">{wallet.history.map(item=><article className="wallet-ledger-row" key={item.id}><div><strong>{item.transaction_type==="gift"?(item.direction==="in"?"Gift received":"Gift sent"):item.transaction_type.replaceAll("_"," ")}</strong><small>{item.direction==="in"?"From":"To"} {item.counterparty}{item.note?" · "+item.note:""}</small><time>{new Date(item.created_at).toLocaleString("en-NG",{dateStyle:"medium",timeStyle:"short"})}</time></div><b className={item.direction==="in"?"credit":"debit"}>{item.direction==="in"?"+":"−"}{fmt(item.amount_ac)} AC{acPerNgn>0&&<small>≈ ₦{fmt(item.amount_ac/acPerNgn)}</small>}</b></article>)}</div>}
  </section>
  <p className="wallet-footnote">AC is an internal AREA currency. Naira figures are reference equivalents only, not redeemable cash value. Purchased AC, package bonuses and earned rewards are recorded as separate ledger entries. No cash-out is available.</p>
 </div>;
}
