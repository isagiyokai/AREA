"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
export default function AdminReportActions({reportId,status}:{reportId:string;status:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState(""),[message,setMessage]=useState("");const router=useRouter();
 async function update(next:"under_review"|"resolved"|"dismissed"){setBusy(true);setError("");setMessage("");try{const {error}=await createClient().rpc("admin_update_content_report",{p_report_id:reportId,p_status:next});if(error)throw error;router.refresh();}catch(e){setError(e instanceof Error?e.message:"Could not update report.");}finally{setBusy(false);}}
 async function sendToWolves(){setBusy(true);setError("");setMessage("");try{const {data,error}=await createClient().rpc("open_community_case",{p_report_id:reportId,p_ac_penalty:0});if(error)throw error;setMessage("Sent to the community court.");router.refresh();}catch(e){setError(e instanceof Error?e.message:"Could not open community case.");}finally{setBusy(false);}}
 return <div className="admin-report-actions"><span>{status.replaceAll("_"," ")}</span><button disabled={busy||status==="under_review"} onClick={()=>void update("under_review")}>Review</button><button disabled={busy} onClick={()=>void update("resolved")}>Resolve</button><button disabled={busy} onClick={()=>void update("dismissed")}>Dismiss</button><button className="wolves-admin-action" disabled={busy||status==="under_review"} onClick={()=>void sendToWolves()}>Thrown to the Wolves ↗</button>{message&&<small className="wallet-success">{message}</small>}{error&&<small className="error">{error}</small>}</div>;
}