import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";

export const dynamic="force-dynamic";

export default async function BookmarksPage(){
 const supabase=await createClient();
 if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();
 if(!user)redirect("/login");
 const {data:blocks}=await supabase.from("user_blocks").select("blocked_user_id").eq("user_id",user.id);
 const blockedUserIds=(blocks??[]).map(row=>row.blocked_user_id);
 const {data:rows}=await supabase.from("post_bookmarks").select("post_id,posts!post_bookmarks_post_id_fkey(id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class))").eq("user_id",user.id).order("created_at",{ascending:false}).limit(40);
 const posts=(rows??[]).flatMap(row=>Array.isArray(row.posts)?row.posts:row.posts?[row.posts]:[]);
 const quoteIds=Array.from(new Set(posts.flatMap(post=>post.quoted_post_id?[post.quoted_post_id]:[])));
 let quoteMap=new Map<string,{id:string;content:string;created_at:string;author_id:string;profiles:unknown}>();
 if(quoteIds.length){const {data:quotes}=await supabase.from("posts").select("id,content,created_at,author_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("id",quoteIds);quoteMap=new Map((quotes??[]).map(q=>[q.id,q]));}
 const hydrated=posts.map(post=>({...post,quoted_post:post.quoted_post_id?quoteMap.get(post.quoted_post_id)??null:null}));
 return <main className="shell bookmarks-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link href="/explore">Explore</Link></nav><div className="top-actions"><Link className="account-link" href="/account">My account</Link></div></header>
  <section className="bookmarks-intro"><span className="eyebrow">YOUR CORNER / PRIVATE COLLECTION</span><h1>Posts worth keeping.</h1><p>Only you can see what you've saved. Keep the gist close.</p></section>
  <Feed initialPosts={hydrated as Parameters<typeof Feed>[0]["initialPosts"]} initialFollowingPosts={[]} signedIn={true} currentUserId={user.id} blockedUserIds={blockedUserIds} loadFallback={false} emptyMessage="Nothing saved yet. Save a post when you want to come back to it." streamTitle="Your saved posts"/>
  <footer className="site-footer"><span>AREA © 2026</span><span>A Nigerian digital society.</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}
