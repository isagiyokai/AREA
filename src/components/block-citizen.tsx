"use client";
import { useEffect,useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

export default function BlockCitizen({profileId,currentUserId}:{profileId:string;currentUserId:string|null}){
 const router=useRouter();
 const [blocked,setBlocked]=useState(false),[busy,setBusy]=useState(false),[ready,setReady]=useState(false),[error,setError]=useState("");
 useEffect(()=>{if(!currentUserId||currentUserId===profileId)return;let active=true;const sb=createClient();void sb.from("user_blocks").select("id").eq("user_id",currentUserId).eq("blocked_user_id",profileId).maybeSingle().then(({data,error})=>{if(!active)return;if(error)setError(error.message);else setBlocked(!!data);setReady(true);});return()=>{active=false;};},[currentUserId,profileId]);
 if(!currentUserId||currentUserId===profileId)return null;
 async function toggle(){if(busy)return;setBusy(true);setError("");try{const sb=createClient();if(blocked){const {error}=await sb.from("user_blocks").delete().eq("user_id",currentUserId).eq("blocked_user_id",profileId);if(error)throw error;setBlocked(false);router.refresh();}else{const {error}=await sb.from("user_blocks").insert({user_id:currentUserId,blocked_user_id:profileId});if(error)throw error;setBlocked(true);router.refresh();}}catch(e){setError(e instanceof Error?e.message:"Could not update block settings.");}finally{setBusy(false);}}
 return <div className="profile-block"><button type="button" className="text-action" onClick={()=>void toggle()} disabled={!ready||busy}>{busy?"Updating…":blocked?"Unblock citizen":"Block citizen"}</button>{error&&<small role="alert">{error}</small>}</div>;
}
