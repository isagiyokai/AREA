import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import CommunityCourt from "@/components/community-court";
export const dynamic="force-dynamic";
export default async function WolvesPage(){
 const supabase=await createClient();if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:rows}=await supabase.from("community_cases").select("id,target_user_id,reason,summary,severity,status,phase,vote_closes_at,created_at,discussion_post_id,offended_user_id,apology_text,apology_submitted_at,apology_accepted_at,reinstated_at,target:profiles!community_cases_target_user_id_fkey(username,display_name,area_class,area_grade)").order("created_at",{ascending:false}).limit(30);
 const {data:feeRow}=await supabase.from("area_economy_settings").select("setting_value").eq("setting_key","community_forgiveness_return_fee_ac").maybeSingle();
 const returnFeeAc=Number(feeRow?.setting_value??500000);
 const ids=(rows??[]).map(row=>row.id);
 const [tallyResult,voteResult,witnessTallyResult,witnessVoteResult]=ids.length?await Promise.all([
  supabase.rpc("get_community_case_tallies",{p_case_ids:ids}),
  supabase.from("community_case_votes").select("case_id,uphold").eq("voter_id",user.id).in("case_id",ids),
  supabase.rpc("get_community_witness_tallies",{p_case_ids:ids}),
  supabase.from("community_case_witness_votes").select("case_id,supports_hearing").eq("voter_id",user.id).in("case_id",ids)
 ]):[{data:[] as {case_id:string;total_votes:number;uphold_votes:number;dismiss_votes:number}[]},{data:[] as {case_id:string;uphold:boolean}[]},{data:[] as {case_id:string;total_votes:number;support_votes:number;oppose_votes:number;report_weight:number;report_count:number}[]},{data:[] as {case_id:string;supports_hearing:boolean}[]}];
 const tallies=(tallyResult.data??[]) as {case_id:string;total_votes:number;uphold_votes:number;dismiss_votes:number}[];
 const myVotes=(voteResult.data??[]) as {case_id:string;uphold:boolean}[];
 const witnessTallies=(witnessTallyResult.data??[]) as {case_id:string;total_votes:number;support_votes:number;oppose_votes:number;report_weight:number;report_count:number}[];
 const myWitnessVotes=(witnessVoteResult.data??[]) as {case_id:string;supports_hearing:boolean}[];
 const tallyMap=new Map<string,{case_id:string;total_votes:number;uphold_votes:number;dismiss_votes:number}>(tallies.map((t:{case_id:string;total_votes:number;uphold_votes:number;dismiss_votes:number})=>[t.case_id,t]));
 const voteMap=new Map<string,boolean>(myVotes.map((v:{case_id:string;uphold:boolean})=>[v.case_id,v.uphold]));
 const witnessTallyMap=new Map(witnessTallies.map(t=>[t.case_id,t]));
 const witnessVoteMap=new Map(myWitnessVotes.map(v=>[v.case_id,v.supports_hearing]));
 const cases=(rows??[]).map(row=>({id:row.id,target_user_id:row.target_user_id,reason:row.reason,summary:row.summary,severity:row.severity,status:row.status,phase:row.phase,vote_closes_at:row.vote_closes_at,created_at:row.created_at,discussion_post_id:row.discussion_post_id,offended_user_id:row.offended_user_id,apology_text:row.apology_text,apology_submitted_at:row.apology_submitted_at,apology_accepted_at:row.apology_accepted_at,reinstated_at:row.reinstated_at,target:Array.isArray(row.target)?row.target[0]??null:row.target,tally:tallyMap.get(row.id)??{total_votes:0,uphold_votes:0,dismiss_votes:0},witness_tally:witnessTallyMap.get(row.id)??{total_votes:0,support_votes:0,oppose_votes:0,report_weight:0,report_count:0},my_vote:voteMap.has(row.id)?voteMap.get(row.id)??null:null,my_witness_vote:witnessVoteMap.has(row.id)?witnessVoteMap.get(row.id)??null:null}));
 return <main className="shell wolves-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/">The street ↗</Link><Link href="/account">My account</Link></div></header>
 <section className="wolves-masthead"><span className="eyebrow">AREA / COMMUNITY JUSTICE</span><h1>Thrown to<br/><em>the Wolves.</em></h1><p>Serious reports come before the community. Read the stated reason. Make your own judgement. One citizen, one vote.</p></section>
 <div className="section-rule"><span>THE COMMUNITY COURT</span><span>ACTIVE CITIZENS ONLY · 24-HOUR VOTE</span></div>
 <CommunityCourt cases={cases} currentUserId={user.id} returnFeeAc={returnFeeAc}/>
 <footer className="site-footer"><span>AREA / COMMUNITY JUDGMENT</span><span>One vote per citizen</span><Link href="/">Back to the street ↗</Link></footer></main>;
}