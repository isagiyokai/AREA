import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import EntryTierChooser from "@/components/entry-tier-chooser";
export const dynamic="force-dynamic";
export default async function EntryPage(){
 const supabase=await createClient();if(!supabase)redirect("/login");const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:profile}=await supabase.from("profiles").select("area_entry_tier").eq("id",user.id).maybeSingle();
 if(profile?.area_entry_tier)redirect("/");
 return <main className="shell entry-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/login">Sign out ↗</Link></div></header><section className="entry-masthead"><span className="eyebrow">AREA / YOUR ENTRY</span><h1>Where do you<br/><em>start from?</em></h1><p>One society. Different starting positions. Your class shapes your opening status, connections and privileges.</p></section><div className="section-rule"><span>THE ENTRY TIERS</span><span>ONE SHARED AREA</span></div><EntryTierChooser/><footer className="site-footer"><span>AREA / ENTRY</span><span>Start your story</span><Link href="/">Back to AREA ↗</Link></footer></main>;
}