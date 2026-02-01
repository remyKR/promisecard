# PromiseCard 프로젝트 규칙

> 베트남 현지 모바일 청첩장 서비스

## 기술 스택

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Backend**: Supabase (Auth, Database, Storage)
- **Deployment**: Vercel
- **Design**: Figma + MCP 연동

---

## 개발 워크플로우

### UI 개발 프로세스

```
[Figma 디자인] → [MCP 연결] → [Claude 구현] → [코드 리뷰]
```

1. **사용자**: Figma에서 UI 디자인 완료
2. **사용자**: Figma MCP 연결
3. **Claude**: 디자인 기반으로 프론트엔드 코드 구현
4. **사용자**: 코드 리뷰 및 피드백

### Figma MCP 연동 규칙

- Figma 디자인이 **없으면 UI 구현하지 않음**
- 디자인과 다른 임의 구현 금지
- 불명확한 부분은 구현 전 질문

### Figma → 코드 변환 규칙

| Figma | 코드 |
|-------|------|
| 컴포넌트 이름 | 파일명 (PascalCase) |
| Auto Layout | Flexbox (`flex`, `gap`) |
| 색상 변수 | Tailwind 색상 또는 CSS 변수 |
| 폰트 스타일 | Tailwind 타이포그래피 |
| 간격 (8px 단위) | Tailwind spacing (`p-2`, `m-4`) |

### 예시

```
Figma 레이어: "Button/Primary"
→ src/components/ui/Button.tsx (variant="primary")

Figma 레이어: "Card/InvitationPreview"
→ src/components/features/InvitationPreview.tsx
```

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

---

## 변경 이력

| 날짜 | 규칙 | 이유 |
|------|------|------|
| 2025-02-01 | 프로젝트 초기 설정 | Next.js + TypeScript + Tailwind |
| 2025-02-01 | enum 금지 | 번들 크기 증가, Tree-shaking 불가 |
| 2025-02-01 | any 타입 금지 | 타입 안정성 확보 |
| 2025-02-01 | interface 대신 type 사용 | 일관성, 확장성 |
| 2025-02-01 | snake_case DB 네이밍 | Supabase/PostgreSQL 컨벤션 |
| 2025-02-01 | Figma MCP 워크플로우 | 디자인 기반 개발, 일관성 확보 |

<!-- 새 규칙 추가 시 위 테이블에 기록해주세요 -->
