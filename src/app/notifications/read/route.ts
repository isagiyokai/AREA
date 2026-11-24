import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request) {
 const supabase=await createClient();
 if(!supabase)return NextResponse.redirect(new URL("/login",request.url),303);
 const {data:{user}}=await supabase.auth.getUser();
 if(!user)return NextResponse.redirect(new URL("/login",request.url),303);
 const form=await request.formData();
 const id=form.get("notification_id");
 if(typeof id==="string"&&id.length>0){
  await supabase.from("notifications").update({read_at:new Date().toISOString()}).eq("id",id).eq("recipient_id",user.id);
 }
 return NextResponse.redirect(new URL("/account",request.url),303);
}