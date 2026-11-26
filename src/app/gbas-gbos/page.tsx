import { createClient } from "@/lib/supabase/server";
import GbasGbosBoard from "@/components/gbas-gbos-board";
export const dynamic="force-dynamic";
export default async function GbasGbosPage(){
 const supabase=await createClient();
 let signedIn=false;let blockedUserIds:string[]=[];let initialPosts:Parameters<typeof GbasGbosBoard>[0]["initialPosts"]=[];let initialChallenges:Parameters<typeof GbasGbosBoard>[0]["initialChallenges"]=[];
 if(supabase){
  const {data:{user}}=await supabase.auth.getUser();signedIn=!!user;
  if(user){const {data:blocks}=await supabase.from("user_blocks").select("blocked_user_id").eq("user_id",user.id);blockedUserIds=(blocks??[]).map(row=>row.blocked_user_id);}
  const blockedSet=new Set(blockedUserIds);
  const [{data:posts},{data:challenges}]=await Promise.all([
   supabase.from("posts").select("id,content,created_at,author_id,profiles(username,display_name,area_class)").order("created_at",{ascending:false}).limit(30),
   supabase.from("argument_challenges").select("id,post_id,challenger_id,challenged_id,intensity,status,created_at,expires_at,posts!argument_challenges_post_id_fkey(id,content),challenger:profiles!argument_challenges_challenger_id_fkey(username,display_name),challenged:profiles!argument_challenges_challenged_id_fkey(username,display_name)").in("status",["pending","active"]).gt("expires_at",new Date().toISOString()).order("created_at",{ascending:false}).limit(30)
  ]);
  const visiblePosts=(posts??[]).filter(p=>!blockedSet.has(p.author_id));
  const visibleChallenges=(challenges??[]).filter(c=>!blockedSet.has(c.challenger_id)&&!blockedSet.has(c.challenged_id));
  const ids=visiblePosts.map(p=>p.id);
  const {data:replies}=ids.length?await supabase.from("replies").select("id,post_id").in("post_id",ids):{data:[]};
  const counts=new Map<string,number>();for(const r of replies??[])counts.set(r.post_id,(counts.get(r.post_id)??0)+1);
  initialPosts=visiblePosts.map(p=>({...p,replyCount:counts.get(p.id)??0})) as typeof initialPosts;
  initialChallenges=visibleChallenges as typeof initialChallenges;
 }
 return <GbasGbosBoard initialPosts={initialPosts} initialChallenges={initialChallenges} signedIn={signedIn}/>;
}
