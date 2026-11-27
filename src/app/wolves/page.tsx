import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import CommunityCourt from "@/components/community-court";
export const dynamic="force-dynamic";
export default async function WolvesPage(){
 const supabase=await createClient();if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:rows}=await supabase.from("community_cases").select("id,reason,summary,status,vote_closes_at,created_at,target:profiles!community_cases_target_user_id_fkey(username,display_name)").order("created_at",{ascending:false}).limit(30);
 const ids=(rows??[]).map(row=>row.id);
 const [{data:tallies},{data:myVotes}]=ids.length?await Promise.all([
  supabase.rpc("get_community_case_tallies",{p_case_ids:ids}),
  supabase.from("community_case_votes").select("case_id,uphold").eq("voter_id",user.id).in("case_id",ids)
 ]):[{data:[]},{data:[]}];
 const tallyMap=new Map((tallies??[]).map(t=>[t.case_id,t]));
 const voteMap=new Map((myVotes??[]).map(v=>[v.case_id,v.uphold]));
 const cases=(rows??[]).map(row=>({id:row.id,reason:row.reason,summary:row.summary,status:row.status,vote_closes_at:row.vote_closes_at,created_at:row.created_at,target:Array.isArray(row.target)?row.target[0]??null:row.target,tally:tallyMap.get(row.id)??{total_votes:0,uphold_votes:0,dismiss_votes:0},my_vote:voteMap.has(row.id)?voteMap.get(row.id)??null:null}));
 return <main className="shell wolves-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/">The street ↗</Link><Link href="/account">My account</Link></div></header>
 <section className="wolves-masthead"><span className="eyebrow">AREA / COMMUNITY JUSTICE</span><h1>Thrown to<br/><em>the Wolves.</em></h1><p>Serious reports come before the community. Read the stated reason. Make your own judgement. One citizen, one vote.</p></section>
 <div className="section-rule"><span>THE COMMUNITY COURT</span><span>ACTIVE CITIZENS ONLY · 24-HOUR VOTE</span></div>
 <CommunityCourt cases={cases}/>
 <footer className="site-footer"><span>AREA / COMMUNITY JUDGMENT</span><span>One vote per citizen</span><Link href="/">Back to the street ↗</Link></footer></main>;
}