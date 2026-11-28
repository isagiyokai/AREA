import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import SocietyHub from "@/components/society-hub";
export const dynamic="force-dynamic";
type CommunityRow={id:string;name:string;slug:string;description:string;created_at:string;created_by:string;creator:{username:string;display_name:string}|{username:string;display_name:string}[]|null};
export default async function SocietyPage(){
 const supabase=await createClient();let signedIn=false,currentUserId:string|null=null;
 if(supabase){const {data:{user}}=await supabase.auth.getUser();signedIn=!!user;currentUserId=user?.id??null;}
 let rows:CommunityRow[]=[];let memberIds:string[]=[];
 if(supabase){const {data}=await supabase.from("area_communities").select("id,name,slug,description,created_at,created_by,creator:profiles!area_communities_created_by_fkey(username,display_name)").order("created_at",{ascending:false}).limit(100);rows=(data??[]) as unknown as CommunityRow[];if(currentUserId){const {data:members}=await supabase.from("area_community_members").select("community_id").eq("user_id",currentUserId);memberIds=(members??[]).map(m=>m.community_id);}}
 const {data:counts}=supabase?await supabase.rpc("get_area_community_counts"):{data:[] as {community_id:string;member_count:number}[]};const countMap=new Map((counts??[]).map(row=>[row.community_id,Number(row.member_count)]));const communities=rows.map(c=>({id:c.id,name:c.name,slug:c.slug,description:c.description,created_at:c.created_at,created_by:c.created_by,member_count:countMap.get(c.id)??0,creator:Array.isArray(c.creator)?c.creator[0]??null:c.creator}));
 return <main className="shell society-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link href="/explore">Explore</Link><Link className="nav-current" href="/society">Society</Link><Link href="/territories">Territories</Link></nav><div className="top-actions"><Link className="account-link" href={signedIn?"/account":"/login"}>{signedIn?"My account":"Sign in"}</Link></div></header>
 <section className="society-masthead"><span className="eyebrow">AREA / SOCIETY</span><h1>Find your <em>people.</em><br/>Build your corner.</h1><p>Communities are where the street becomes smaller. Gather around the things you love, argue over what matters and build something with people who get it.</p></section>
 <div className="section-rule"><span>THE SOCIETY</span><span>BUILT BY CITIZENS</span></div>
 <SocietyHub communities={communities} memberIds={memberIds} currentUserId={currentUserId} signedIn={signedIn}/>
 <footer className="site-footer"><span>AREA / SOCIETY</span><span>Different corners. One society.</span><Link href="/">Back to the street ↗</Link></footer></main>;
}