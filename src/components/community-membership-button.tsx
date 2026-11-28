"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
export default function CommunityMembershipButton({communityId,isMember,isOwner,signedIn}:{communityId:string;isMember:boolean;isOwner:boolean;signedIn:boolean}){
 const router=useRouter();const [busy,setBusy]=useState(false),[error,setError]=useState("");
 async function toggle(){if(!signedIn){router.push("/login");return;}setBusy(true);setError("");try{const sb=createClient();const {data:{user}}=await sb.auth.getUser();if(!user)throw new Error("Sign in to continue.");const result=isMember?await sb.from("area_community_members").delete().eq("community_id",communityId).eq("user_id",user.id).eq("role","member"):await sb.rpc("join_area_community",{p_community_id:communityId});if(result.error)throw result.error;router.refresh();}catch(e){setError(e instanceof Error?e.message:"Could not update membership.");}finally{setBusy(false);}}
 return <div className="society-membership-action">{isOwner?<span className="society-owner-tag">FOUNDER</span>:<button className={isMember?"btn":"btn primary"} disabled={busy} onClick={()=>void toggle()}>{busy?"Updating…":isMember?"Leave community":"Join community"}</button>}{error&&<small className="error">{error}</small>}</div>;
}