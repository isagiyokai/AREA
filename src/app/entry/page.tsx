import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import EntryTierChooser from "@/components/entry-tier-chooser";
export const dynamic="force-dynamic";
export default async function EntryPage(){
 const supabase=await createClient();if(!supabase)redirect("/login");const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:isAdmin}=await supabase.rpc("is_area_admin_profile",{p_user_id:user.id});
 if(isAdmin)redirect("/");
 const {data:profile}=await supabase.from("profiles").select("area_entry_tier").eq("id",user.id).maybeSingle();
 if(profile?.area_entry_tier)redirect("/");
 return <main className="shell entry-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><form action="/auth/signout" method="post"><button className="text-action" type="submit">Sign out</button></form></div></header><section className="entry-masthead"><span className="eyebrow">AREA / YOUR ENTRY</span><h1>Where do you<br/><em>start from?</em></h1><p>One society. Different starting positions. Your class shapes your opening status, connections and privileges.</p></section><div className="section-rule"><span>THE ENTRY TIERS</span><span>ONE SHARED AREA</span></div><EntryTierChooser paymentsEnabled={(process.env.AREA_PAYMENTS_ENABLED === "true" && Boolean(process.env.PAYSTACK_SECRET_KEY&&process.env.PAYSTACK_WEBHOOK_SECRET&&process.env.SUPABASE_SERVICE_ROLE_KEY&&process.env.NEXT_PUBLIC_SITE_URL))}/><footer className="site-footer"><span>AREA / ENTRY</span><span>Start your story</span><Link href="/">Back to AREA ↗</Link></footer></main>;
}