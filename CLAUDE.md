# PromiseCard 프로젝트 규칙

> 베트남 현지 모바일 청첩장 서비스

## 기술 스택

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Backend**: Supabase (Auth, Database, Storage)
- **Deployment**: Vercel

---

## 코딩 컨벤션

### TypeScript

- `interface` 대신 `type` 사용
- `enum` 금지 → string literal union 사용
- `any` 타입 금지 → `unknown` 사용 후 타입 가드

```typescript
// ✅ Good
type Status = 'draft' | 'published' | 'archived'

// ❌ Bad
enum Status { Draft, Published, Archived }
```

### 컴포넌트

- 함수형 컴포넌트만 사용
- 파일명: PascalCase (`CardTemplate.tsx`)
- export default 사용

```typescript
// ✅ Good
export default function CardTemplate() {
  return <div>...</div>
}
```

### 폴더 구조

```
src/
├── app/                 # 페이지 (App Router)
├── components/          # 재사용 컴포넌트
│   ├── ui/             # 기본 UI (Button, Input 등)
│   └── features/       # 기능별 컴포넌트
├── lib/                # 유틸리티, 헬퍼
├── hooks/              # 커스텀 훅
├── types/              # 타입 정의
└── styles/             # 전역 스타일
```

---

## Tailwind CSS

- 인라인 클래스 우선 (CSS 파일 최소화)
- 반복되는 스타일 → `@apply` 또는 컴포넌트화
- 색상: Tailwind 기본 팔레트 사용

```tsx
// ✅ Good - 직관적인 클래스명
<button className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600">

// ❌ Bad - 불필요한 CSS 파일
<button className={styles.button}>
```

---

## Supabase 규칙

### 환경변수

```env
NEXT_PUBLIC_SUPABASE_URL=your-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-key
```

### 클라이언트 생성

```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)
```

### 데이터베이스 네이밍

- 테이블명: snake_case 복수형 (`invitation_cards`)
- 컬럼명: snake_case (`created_at`)

---

## 금지 사항

- ❌ `console.log` 커밋 금지
- ❌ 하드코딩된 API URL 금지
- ❌ `!important` 사용 금지
- ❌ 인라인 스타일 (`style={}`) 금지

---

## Git 커밋 메시지

```
feat: 새 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅
refactor: 리팩토링
chore: 빌드, 설정 변경
```

예시: `feat: 청첩장 템플릿 선택 기능 추가`

---

## 다국어 지원

- 기본 언어: 한국어 (ko)
- 지원 언어: 베트남어 (vi)
- 텍스트 하드코딩 금지 → i18n 키 사용

---

## 참고 문서

- [Next.js Docs](https://nextjs.org/docs)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [Supabase Docs](https://supabase.com/docs)
