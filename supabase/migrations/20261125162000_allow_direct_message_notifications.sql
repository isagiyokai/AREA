alter table public.notifications drop constraint if exists notifications_notification_type_check;
alter table public.notifications add constraint notifications_notification_type_check
check (notification_type = any (array[
 'argument_invitation','argument_response','argument_escalation','escalation_response',
 'post_reply','quote_post','mention_post','mention_reply','direct_message'
]::text[]));