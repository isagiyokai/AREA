"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Profile = { username: string; display_name: string; area_class: string };
type Post = {
  id: string;
  content: string;
  created_at: string;
  author_id: string;
  profiles: Profile | Profile[] | null;
};
type Reply = {
  id: string;
  post_id: string;
  content: string;
  created_at: string;
  author_id: string;
  profiles: Profile | Profile[] | null;
};

function getProfile(item: { profiles: Profile | Profile[] | null }): Profile | null {
  return Array.isArray(item.profiles) ? item.profiles[0] ?? null : item.profiles;
}

function displayTime(value: string) {
  return new Date(value).toLocaleString();
}

export default function Feed({
  initialPosts,
  signedIn,
}: {
  initialPosts: Post[];
  signedIn: boolean;
}) {
  const [posts, setPosts] = useState(initialPosts);
  const [content, setContent] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [openPostId, setOpenPostId] = useState<string | null>(null);
  const [repliesByPost, setRepliesByPost] = useState<Record<string, Reply[]>>({});
  const [replyDrafts, setReplyDrafts] = useState<Record<string, string>>({});
  const [loadingReplies, setLoadingReplies] = useState<string | null>(null);
  const [replyBusy, setReplyBusy] = useState<string | null>(null);
  const [replyErrors, setReplyErrors] = useState<Record<string, string>>({});

  async function publish() {
    setError("");
    const text = content.trim();
    if (!text || text.length > 500) return;
    if (!signedIn) {
      window.location.href = "/login";
      return;
    }

    setBusy(true);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Please sign in again.");

      const { data, error } = await supabase
        .from("posts")
        .insert({ author_id: user.id, content: text })
        .select("id,content,created_at,author_id,profiles(username,display_name,area_class)")
        .single();

      if (error) throw error;
      setPosts((current) => [data as Post, ...current]);
      setContent("");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not publish. Try again.");
    } finally {
      setBusy(false);
    }
  }

  async function toggleReplies(postId: string) {
    if (openPostId === postId) {
      setOpenPostId(null);
      return;
    }

    setOpenPostId(postId);
    if (repliesByPost[postId]) return;

    setLoadingReplies(postId);
    setReplyErrors((current) => ({ ...current, [postId]: "" }));
    try {
      const supabase = createClient();
      const { data, error } = await supabase
        .from("replies")
        .select("id,post_id,content,created_at,author_id,profiles(username,display_name,area_class)")
        .eq("post_id", postId)
        .order("created_at", { ascending: true });

      if (error) throw error;
      setRepliesByPost((current) => ({ ...current, [postId]: (data ?? []) as Reply[] }));
    } catch (e) {
      setReplyErrors((current) => ({
        ...current,
        [postId]: e instanceof Error ? e.message : "Could not load replies.",
      }));
    } finally {
      setLoadingReplies(null);
    }
  }

  async function submitReply(postId: string) {
    const text = (replyDrafts[postId] ?? "").trim();
    if (!text || text.length > 300) return;
    if (!signedIn) {
      window.location.href = "/login";
      return;
    }

    setReplyBusy(postId);
    setReplyErrors((current) => ({ ...current, [postId]: "" }));
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Please sign in again.");

      const { data, error } = await supabase
        .from("replies")
        .insert({ post_id: postId, author_id: user.id, content: text })
        .select("id,post_id,content,created_at,author_id,profiles(username,display_name,area_class)")
        .single();

      if (error) throw error;
      setRepliesByPost((current) => ({
        ...current,
        [postId]: [...(current[postId] ?? []), data as Reply],
      }));
      setReplyDrafts((current) => ({ ...current, [postId]: "" }));
    } catch (e) {
      setReplyErrors((current) => ({
        ...current,
        [postId]: e instanceof Error ? e.message : "Could not send your reply.",
      }));
    } finally {
      setReplyBusy(null);
    }
  }

  return (
    <>
      <div className="compose">
        <h2 className="heading">What's happening in your AREA?</h2>
        <textarea
          maxLength={500}
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder={signedIn ? "Drop the gist. Keep it real…" : "Sign in to join the conversation."}
        />
        <div className="composefoot">
          <span>{content.length}/500 characters</span>
          <button className="btn primary" onClick={publish} disabled={busy || !content.trim()}>
            {busy ? "Posting…" : "Post to AREA"}
          </button>
        </div>
        {error && <p className="error">{error}</p>}
      </div>

      <div className="feed-divider">
        <h2 className="heading">Fresh from the street</h2>
        {posts.length === 0 ? (
          <div className="empty">The street is quiet. Be the first to start the gist.</div>
        ) : (
          posts.map((post) => {
            const profile = getProfile(post);
            const replies = repliesByPost[post.id] ?? [];
            const isOpen = openPostId === post.id;

            return (
              <article className="post" key={post.id}>
                <div className="posthead">
                  <div className="avatar">{(profile?.display_name || "A").slice(0, 1).toUpperCase()}</div>
                  <div>
                    <div className="postname">
                      {profile?.display_name || "AREA Citizen"}{" "}
                      <span className="tag">{(profile?.area_class || "slums").toUpperCase()}</span>
                    </div>
                    <div className="meta">
                      @{profile?.username || "citizen"} · {displayTime(post.created_at)}
                    </div>
                  </div>
                </div>
                <p className="content">{post.content}</p>
                <div className="actions">
                  <button className="text-action" onClick={() => void toggleReplies(post.id)}>
                    {isOpen ? "Close conversation" : "Reply / view conversation"}
                    {replies.length > 0 ? ` · ${replies.length}` : ""}
                  </button>
                  <span>↗ Share</span>
                </div>

                {isOpen && (
                  <section className="reply-panel" aria-label="Post conversation">
                    <h3 className="reply-heading">The conversation</h3>
                    {loadingReplies === post.id ? (
                      <p className="notice">Loading replies…</p>
                    ) : replies.length === 0 ? (
                      <p className="notice">No replies yet. You can start the conversation.</p>
                    ) : (
                      <div className="reply-list">
                        {replies.map((reply) => {
                          const replyProfile = getProfile(reply);
                          return (
                            <div className="reply-item" key={reply.id}>
                              <div className="reply-meta">
                                <strong>{replyProfile?.display_name || "AREA Citizen"}</strong>
                                <span>@{replyProfile?.username || "citizen"}</span>
                                <span>· {displayTime(reply.created_at)}</span>
                              </div>
                              <p>{reply.content}</p>
                            </div>
                          );
                        })}
                      </div>
                    )}
                    {replyErrors[post.id] && <p className="error">{replyErrors[post.id]}</p>}
                    <div className="reply-compose">
                      <textarea
                        maxLength={300}
                        value={replyDrafts[post.id] ?? ""}
                        onChange={(e) =>
                          setReplyDrafts((current) => ({ ...current, [post.id]: e.target.value }))
                        }
                        placeholder={signedIn ? "Add your reply…" : "Sign in to reply…"}
                        aria-label="Write a reply"
                      />
                      <div className="reply-compose-footer">
                        <span>{(replyDrafts[post.id] ?? "").length}/300</span>
                        <button
                          className="btn primary"
                          onClick={() => void submitReply(post.id)}
                          disabled={replyBusy === post.id || !(replyDrafts[post.id] ?? "").trim()}
                        >
                          {replyBusy === post.id ? "Sending…" : "Reply"}
                        </button>
                      </div>
                    </div>
                  </section>
                )}
              </article>
            );
          })
        )}
      </div>

      <p className="notice">
        Keep the banter lively. Threats, doxxing, stalking and targeted harassment have no place here.
      </p>
      {!signedIn && (
        <p className="notice">
          <Link href="/signup" className="green">Create your citizen account</Link> to post and take part.
        </p>
      )}
    </>
  );
}
