"use client";
import { useEffect,useState } from "react";
import { createClient } from "@/lib/supabase/client";

type LedgerItem={id:string;amount_ac:number;transaction_type:string;note:string|null;created_at:string;direction:"in"|"out";counterparty:string};
type Wallet={balance_ac:number;history:LedgerItem[]};
const fmt=(n:number)=>new Intl.NumberFormat("en-NG").format(n);
export default function AcWalletPanel({initialWallet}:{initialWallet:Wallet|null}){
 const [wallet,setWallet]=useState<Wallet|null>(initialWallet),[loading,setLoading]=useState(!initialWallet),[username,setUsername]=useState(""),[amount,setAmount]=useState(""),[note,setNote]=useState(""),[busy,setBusy]=useState(false),[message,setMessage]=useState(""),[error,setError]=useState("");
 async function refresh(){const sb=createClient();const {data,error}=await sb.rpc("get_my_ac_wallet");if(error)throw error;setWallet(data as Wallet);setLoading(false);}
 useEffect(()=>{if(!initialWallet)void refresh().catch(e=>{setError(e instanceof Error?e.message:"Wallet unavailable.");setLoading(false);});},[]);
 async function send(){setBusy(true);setError("");setMessage("");try{const sb=createClient();const {data,error}=await sb.rpc("transfer_ac",{p_recipient_username:username.trim().replace(/^@/,""),p_amount:Number(amount),p_note:note.trim()||null});if(error)throw error;const result=data as {balance_ac:number;amount_ac:number;recipient_username:string};setMessage(`Sent ${fmt(result.amount_ac)} AC to @${result.recipient_username}.`);setUsername("");setAmount("");setNote("");await refresh();}catch(e){setError(e instanceof Error?e.message:"Transfer could not be completed.");}finally{setBusy(false);}}
 return <div className="wallet-layout">
  <section className="wallet-balance"><span className="mini-label">YOUR AVAILABLE BALANCE</span><div className="wallet-amount">{loading?"…":fmt(wallet?.balance_ac??0)} <small>AC</small></div><p>AREA currency · kept inside the society</p><div className="wallet-balance-foot"><span>NO CASH VALUE YET</span><span>WALLET / 001</span></div></section>
  <section className="wallet-transfer"><div className="wallet-section-head"><div><span className="mini-label">MOVE AC</span><h2>Send a citizen a gift</h2></div><span className="wallet-index">01 / TRANSFER</span></div>
   <label>Citizen username<input value={username} onChange={e=>setUsername(e.target.value)} placeholder="@username" maxLength={25}/></label>
   <label>Amount in AC<input value={amount} onChange={e=>setAmount(e.target.value.replace(/[^0-9]/g,""))} inputMode="numeric" placeholder="e.g. 25000"/></label>
   <label>Note <span className="wallet-optional">OPTIONAL</span><input value={note} onChange={e=>setNote(e.target.value)} placeholder="What's it for?" maxLength={120}/></label>
   <button className="btn primary" disabled={busy||!username.trim()||!amount||Number(amount)<1} onClick={()=>void send()}>{busy?"Sending…":"Send AC ↗"}</button>
   {message&&<p className="wallet-success">{message}</p>}{error&&<p className="error">{error}</p>}
  </section>
  <section className="wallet-history"><div className="wallet-section-head"><div><span className="mini-label">MONEY MOVES</span><h2>Recent transactions</h2></div><span className="wallet-index">LAST 40</span></div>
   {!wallet?.history?.length?<p className="notice">Nothing has moved yet. Your AC activity will appear here.</p>:<div className="wallet-ledger">{wallet.history.map(item=><article className="wallet-ledger-row" key={item.id}><div><strong>{item.transaction_type==="gift"?(item.direction==="in"?"Gift received":"Gift sent"):item.transaction_type.replaceAll("_"," ")}</strong><small>{item.direction==="in"?"From":"To"} {item.counterparty}{item.note?" · "+item.note:""}</small><time>{new Date(item.created_at).toLocaleString("en-NG",{dateStyle:"medium",timeStyle:"short"})}</time></div><b className={item.direction==="in"?"credit":"debit"}>{item.direction==="in"?"+":"−"}{fmt(item.amount_ac)} AC</b></article>)}</div>}
  </section>
  <p className="wallet-footnote">AC is an internal AREA currency. Wallet transfers are live; naira purchases, cash-out and external payment processing are not enabled yet. Purchased AC will be accounted for separately from promotional or earned AC.</p>
 </div>;
}