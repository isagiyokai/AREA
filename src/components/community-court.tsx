"use client";
import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type CaseRow={
 id:string;reason:string;summary:string;severity:string;status:string;phase:"witnessing"|"judgment";vote_closes_at:string;created_at:string;
 discussion_post_id:string|null;offended_user_id:string|null;apology_text:string|null;apology_submitted_at:string|null;apology_accepted_at:string|null;reinstated_at:string|null;
 target:{username:string;display_name:string;area_class:string|null;area_grade:string|null}|null;
 tally:{total_votes:number;uphold_votes:number;dismiss_votes:number};
 witness_tally:{total_votes:number;support_votes:number;oppose_votes:number;report_weight:number;report_count:number};
 my_vote:boolean|null;my_witness_vote:boolean|null;
};

export default function CommunityCourt({cases,currentUserId}:{cases:CaseRow[];currentUserId:string}){
 const router=useRouter();
 const [busy,setBusy]=useState<string|null>(null),[error,setError]=useState(""),[apologies,setApologies]=useState<Record<string,string>>({});
 async function act(id:string,fn:string,args:Record<string,unknown>){
  setBusy(id);setError("");
  try{const {error}=await createClient().rpc(fn,args);if(error)throw error;router.refresh();}
  catch(e){setError(e instanceof Error?e.message:"The community action could not be completed.");}
  finally{setBusy(null);}
 }
 const date=(value:string)=>new Date(value).toLocaleString("en-NG",{dateStyle:"medium",timeStyle:"short"});
 return <div className="wolves-list">
  {error&&<p className="error" role="alert">{error}</p>}
  {!cases.length?<p className="notice">No conversations have been brought before the community. The yard is quiet.</p>:cases.map(item=>{
   const expired=new Date(item.vote_closes_at).getTime()<=Date.now();
   const witnessing=item.phase==="witnessing";
   const target=item.target;
   const isTarget=target&&false;
   return <article className="wolves-case" id={"case-"+item.id} key={item.id}>
    <div className="wolves-case-top"><span className="mini-label">{item.severity.toUpperCase()} SEVERITY / {item.id.slice(0,8).toUpperCase()}</span><b className={"wolves-status "+item.status}>{witnessing?"WITNESS REVIEW":item.status.replaceAll("_"," ").toUpperCase()}</b></div>
    <h2>{target?.display_name||"AREA citizen"} <small>@{target?.username||"unknown"}</small></h2>
    <div className="wolves-citizen-standing">{target?.area_class?.toUpperCase()||"CLASS UNKNOWN"}{target?.area_grade?" · "+target.area_grade:""}</div>
    <div className="wolves-reason">REPORTED FOR: {item.reason.replaceAll("_"," ")}</div>
    <p>{item.summary}</p>
    {item.discussion_post_id&&<p><Link className="text-action" href={"/p/"+item.discussion_post_id}>Read the full conversation ↗</Link></p>}
    {witnessing?<div className="wolves-stage-panel">
      <strong>STAGE ONE / THE WITNESSES</strong>
      <p>Should this conversation proceed to The Wolves for a full community judgment? Observer reports carry double weight when establishing a hearing. Each eligible citizen still gets one vote.</p>
      <div className="wolves-tally"><span><b>{item.witness_tally.support_votes}</b> Proceed</span><span><b>{item.witness_tally.oppose_votes}</b> Close</span><span><b>{item.witness_tally.report_count}</b> Reports · {item.witness_tally.report_weight} weight</span></div>
      {!expired&&item.status==="voting"&&<div className="wolves-vote-actions">
       <button className="btn primary" disabled={busy===item.id||item.my_witness_vote===true} onClick={()=>void act(item.id,"vote_community_witness_case",{p_case_id:item.id,p_supports_hearing:true})}>{item.my_witness_vote===true?"You voted proceed":"Send to The Wolves"}</button>
       <button className="btn" disabled={busy===item.id||item.my_witness_vote===false} onClick={()=>void act(item.id,"vote_community_witness_case",{p_case_id:item.id,p_supports_hearing:false})}>{item.my_witness_vote===false?"You voted close":"Close the matter"}</button>
      </div>}
      {expired&&item.status==="voting"&&<button className="btn primary" disabled={busy===item.id} onClick={()=>void act(item.id,"resolve_community_witness_case",{p_case_id:item.id})}>Call the witnesses' result ↗</button>}
     </div>:<div className="wolves-stage-panel">
      <strong>STAGE TWO / THE WOLVES</strong>
      <p>The hearing is authorized. Decide whether the conduct should be upheld. If upheld, the citizen serves a 24-hour penance unless a direct apology is accepted and the return fee is paid.</p>
      <div className="wolves-tally"><span><b>{item.tally.uphold_votes}</b> Uphold</span><span><b>{item.tally.dismiss_votes}</b> Dismiss</span><span><b>{item.tally.total_votes}</b> Votes</span></div>
      {!expired&&item.status==="voting"&&<div className="wolves-vote-actions">
       <button className="btn primary" disabled={busy===item.id||item.my_vote===true} onClick={()=>void act(item.id,"vote_community_case",{p_case_id:item.id,p_uphold:true})}>{item.my_vote===true?"You voted uphold":"Uphold the case"}</button>
       <button className="btn" disabled={busy===item.id||item.my_vote===false} onClick={()=>void act(item.id,"vote_community_case",{p_case_id:item.id,p_uphold:false})}>{item.my_vote===false?"You voted dismiss":"Dismiss the case"}</button>
      </div>}
      {expired&&item.status==="voting"&&<button className="btn primary" disabled={busy===item.id} onClick={()=>void act(item.id,"resolve_community_case",{p_case_id:item.id})}>Call the Wolves' verdict ↗</button>}
     </div>}
    {item.status==="upheld"&&!item.reinstated_at&&<div className="wolves-result"><strong>The community upheld the case.</strong><p>A 24-hour penance applies. A direct apology may create an earlier path back.</p></div>}
    {item.status==="upheld"&&item.offended_user_id&&item.apology_accepted_at===null&&currentUserId===target?.username&&null}
    {item.status==="upheld"&&item.apology_text&&<div className="wolves-apology"><strong>APOLOGY FROM THE CITIZEN</strong><p>{item.apology_text}</p>{item.apology_submitted_at&&<small>Submitted {date(item.apology_submitted_at)}</small>}
      {currentUserId===item.offended_user_id&&<button className="btn primary" disabled={busy===item.id} onClick={()=>void act(item.id,"accept_community_apology",{p_case_id:item.id})}>Accept apology · reinstate for the configured fee</button>}
     </div>}
    {item.status==="upheld"&&!item.reinstated_at&&currentUserId===item.target?.username&&null}
    {item.status==="upheld"&&!item.reinstated_at&&item.offended_user_id&&<ApologyComposer caseId={item.id} currentUserId={currentUserId} targetUsername={target?.username??""} value={apologies[item.id]??""} onChange={value=>setApologies(v=>({...v,[item.id]:value}))} busy={busy===item.id} onSubmit={()=>void act(item.id,"request_community_apology",{p_case_id:item.id,p_apology:apologies[item.id]??""})}/>}
    {item.reinstated_at&&<p className="wolves-result">Apology accepted. The citizen paid the return fee and has been reinstated. <small>{date(item.reinstated_at)}</small></p>}
    {item.status==="dismissed"&&<p className="wolves-result">The community did not uphold the case. No penance applies.</p>}
    {item.status==="insufficient_votes"&&<p className="wolves-result">Not enough eligible votes. No penalty applies.</p>}
    <footer>Opened {date(item.created_at)} · {expired?"Voting period ended":"Closes "+date(item.vote_closes_at)}</footer>
   </article>;
  })}
 </div>;
}

function ApologyComposer({caseId,currentUserId,targetUsername,value,onChange,busy,onSubmit}:{caseId:string;currentUserId:string;targetUsername:string;value:string;onChange:(value:string)=>void;busy:boolean;onSubmit:()=>void}){
 const [isTarget,setIsTarget]=useState(false);
 return <div className="wolves-apology-compose">
  <label htmlFor={"apology-"+caseId}>Your apology to the person affected</label>
  <textarea id={"apology-"+caseId} value={value} maxLength={1000} onChange={e=>onChange(e.target.value)} placeholder="Acknowledge what happened and apologise directly…" rows={3}/>
  <button className="btn" disabled={busy||value.trim().length<10} onClick={onSubmit}>Submit apology for their decision</button>
 </div>;
}
