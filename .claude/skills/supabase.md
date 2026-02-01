# Supabase 사용 가이드

PromiseCard 프로젝트의 Supabase 연동 지식입니다.

## 환경 설정

```env
# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # 서버 전용
```

## 클라이언트 설정

### 브라우저 클라이언트

```typescript
// src/lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

### 서버 클라이언트

```typescript
// src/lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          )
        },
      },
    }
  )
}
```

## 인증 (Auth)

### 회원가입

```typescript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'password123',
})
```

### 로그인

```typescript
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password123',
})
```

### 소셜 로그인

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: {
    redirectTo: `${origin}/auth/callback`,
  },
})
```

### 로그아웃

```typescript
await supabase.auth.signOut()
```

### 현재 유저

```typescript
const { data: { user } } = await supabase.auth.getUser()
```

## 데이터베이스 (Database)

### 조회 (SELECT)

```typescript
// 전체 조회
const { data, error } = await supabase
  .from('invitation_cards')
  .select('*')

// 조건 조회
const { data, error } = await supabase
  .from('invitation_cards')
  .select('*')
  .eq('user_id', userId)
  .eq('status', 'published')

// 단일 조회
const { data, error } = await supabase
  .from('invitation_cards')
  .select('*')
  .eq('share_code', code)
  .single()
```

### 생성 (INSERT)

```typescript
const { data, error } = await supabase
  .from('invitation_cards')
  .insert({
    user_id: userId,
    groom_name: '홍길동',
    bride_name: '김영희',
    wedding_date: '2025-05-01T11:00:00Z',
    venue_name: '더파티움',
    venue_address: '서울시 강남구...',
  })
  .select()
  .single()
```

### 수정 (UPDATE)

```typescript
const { data, error } = await supabase
  .from('invitation_cards')
  .update({ status: 'published' })
  .eq('id', cardId)
  .select()
  .single()
```

### 삭제 (DELETE)

```typescript
const { error } = await supabase
  .from('invitation_cards')
  .delete()
  .eq('id', cardId)
```

## 스토리지 (Storage)

### 버킷 생성

Supabase Dashboard에서 `invitation-images` 버킷 생성

### 파일 업로드

```typescript
const { data, error } = await supabase.storage
  .from('invitation-images')
  .upload(`${userId}/${fileName}`, file, {
    cacheControl: '3600',
    upsert: false,
  })
```

### 공개 URL 가져오기

```typescript
const { data } = supabase.storage
  .from('invitation-images')
  .getPublicUrl(`${userId}/${fileName}`)

// data.publicUrl
```

### 파일 삭제

```typescript
const { error } = await supabase.storage
  .from('invitation-images')
  .remove([`${userId}/${fileName}`])
```

## RLS (Row Level Security) 정책

```sql
-- 본인 청첩장만 조회/수정/삭제 가능
CREATE POLICY "Users can manage own cards"
ON invitation_cards
FOR ALL
USING (auth.uid() = user_id);

-- 공개된 청첩장은 누구나 조회 가능
CREATE POLICY "Published cards are public"
ON invitation_cards
FOR SELECT
USING (status = 'published');
```

## 타입 생성

```bash
npx supabase gen types typescript --project-id xxx > src/types/database.ts
```

## 에러 처리 패턴

```typescript
const { data, error } = await supabase
  .from('invitation_cards')
  .select('*')

if (error) {
  console.error('Supabase error:', error.message)
  throw new Error('청첩장을 불러오는데 실패했습니다.')
}

return data
```
