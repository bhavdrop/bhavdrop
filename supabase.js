import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://yrfjqpzqmhddlxbwmsgb.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_so1k3P8YeQNeydSvFF9PpQ_vscf0rz9';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
