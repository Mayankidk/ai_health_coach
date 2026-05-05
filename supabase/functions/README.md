# Supabase Edge Functions

## AI Coach

`ai-coach` proxies Gemini requests so the Flutter Android and web clients never
ship `GEMINI_API_KEY`.

### Secrets

Set the Gemini key in Supabase:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
```

For local function development, create `supabase/functions/.env` from
`supabase/functions/.env.example`.

### Deploy

```bash
supabase functions deploy ai-coach
```

### Client requirements

The function requires a Supabase Auth user session. Anonymous Supabase users are
accepted because they still receive a user JWT, but calls with only the public
anon key are rejected.
