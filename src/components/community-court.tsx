"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
type CaseRow={id:string;reason:string;summary:string;severity:string;status:string;vote_closes_at:string;created_at:string;target: {username:string;display_name:string}|null;tally:{total_votes:number;uphold_votes:number;dismiss_votes:number};my_vote:boolean|null};
export default function CommunityCourt({cases}:{cases:CaseRow[]}){
 const router=useRouter();const [busy,setBusy]=useState<string|null>(null);const [error,setError]=useState("");
 async function vote(id:string,uphold:boolean){setBusy(id);setError("");try{const {error}=await createClient().rpc("vote_community_case",{p_case_id:id,p_uphold:uphold});if(error)throw error;router.refresh();}catch(e){setError(e instanceof Error?e.message:"Your vote could not be recorded.");}finally{setBusy(null);}}
 async function resolve(id:string){setBusy(id);setError("");try{const {error}=await createClient().rpc("resolve_community_case",{p_case_id:id});if(error)throw error;router.refresh();}catch(e){setError(e instanceof Error?e.message:"Could not close this vote.");}finally{setBusy(null);}}
 return <div className="wolves-list">{error&&<p className="error">{error}</p>}{!cases.length?<p className="notice">No cases have been brought before the Wolves. The yard is quiet.</p>:cases.map(item=>{const closed=item.status!=="voting";const expired=new Date(item.vote_closes_at).getTime()<=Date.now();return <article className="wolves-case" id={"case-"+item.id} key={item.id}>
  <div className="wolves-case-top"><span className="mini-label">{item.severity.toUpperCase()} SEVERITY / {item.id.slice(0,8).toUpperCase()}</span><b className={"wolves-status "+item.status}>{item.status.replaceAll("_"," ")}</b></div>
  <h2>{item.target?.display_name||"AREA citizen"} <small>@{item.target?.username||"unknown"}</small></h2>
  <div className="wolves-reason">REPORTED FOR: {item.reason.replaceAll("_"," ")}</div><p>{item.summary}</p>
  <div className="wolves-tally"><span><b>{item.tally.uphold_votes}</b> Uphold</span><span><b>{item.tally.dismiss_votes}</b> Dismiss</span><span><b>{item.tally.total_votes}</b> Votes</span></div>
  {!closed&&!expired?<div className="wolves-vote-actions"><button className="btn primary" disabled={busy===item.id||item.my_vote===true} onClick={()=>void vote(item.id,true)}>{item.my_vote===true?"You voted uphold":"Uphold the case"}</button><button className="btn" disabled={busy===item.id||item.my_vote===false} onClick={()=>void vote(item.id,false)}>{item.my_vote===false?"You voted dismiss":"Dismiss the case"}</button></div>:null}
  {!closed&&expired?<button className="btn primary" disabled={busy===item.id} onClick={()=>void resolve(item.id)}>Call the result ↗</button>:null}
  {closed&&item.status==="upheld"?<p className="wolves-result">The community upheld the case. A 24-hour penance applies.</p>:null}
  {closed&&item.status==="dismissed"?<p className="wolves-result">The community did not uphold the case. No penance applies.</p>:null}
  {closed&&item.status==="insufficient_votes"?<p className="wolves-result">Not enough eligible votes. No penalty applies.</p>:null}
  <footer>Opened {new Date(item.created_at).toLocaleDateString("en-NG",{dateStyle:"medium"})} · {closed?"Vote closed":expired?"Ready for result":"Closes "+new Date(item.vote_closes_at).toLocaleString("en-NG",{dateStyle:"medium",timeStyle:"short"})}</footer>
 </article>})}</div>;
}