"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function FollowButton({
 profileId,
 currentUserId,
 initialFollowing,
 initialFollowers
}:{
 profileId:string;
 currentUserId:string|null;
 initialFollowing:boolean;
 initialFollowers:number;
}){
 const [following,setFollowing]=useState(initialFollowing);
 const [followers,setFollowers]=useState(initialFollowers);
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState("");

 async function toggle(){
  if(!currentUserId){window.location.href="/login";return;}
  if(currentUserId===profileId)return;
  setBusy(true);
  setError("");
  try{
   const supabase=createClient();
   if(following){
    const {error}=await supabase.from("follows").delete()
     .eq("follower_id",currentUserId).eq("followed_id",profileId);
    if(error)throw error;
    setFollowing(false);
    setFollowers(v=>Math.max(0,v-1));
   }else{
    const {error}=await supabase.from("follows").insert({
     follower_id:currentUserId,
     followed_id:profileId
    });
    if(error)throw error;
    setFollowing(true);
    setFollowers(v=>v+1);
   }
  }catch(e){
   setError(e instanceof Error?e.message:"Could not update this connection.");
  }finally{setBusy(false);}
 }

 if(currentUserId===profileId)return <span className="own-profile-note">THIS IS YOUR PROFILE</span>;
 return <div className="follow-control">
  <button type="button" className={following?"btn follow-button is-following":"btn primary follow-button"} onClick={()=>void toggle()} disabled={busy} aria-pressed={following}>
   {busy?"One moment…":following?"Following ·":"Follow this citizen"}
  </button>
  <span className="follow-count"><strong>{followers}</strong> {followers===1?"follower":"followers"}</span>
  {error&&<span className="error follow-error" role="alert">{error}</span>}
 </div>;
}