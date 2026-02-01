# Page Generator

`$ARGUMENTS` 이름으로 Next.js 페이지를 생성해주세요.

## 생성 위치

`src/app/$ARGUMENTS/page.tsx`

## 규칙

1. App Router 구조 사용
2. TypeScript 사용
3. 메타데이터 포함 (SEO)
4. Tailwind CSS 스타일링

## 템플릿

```tsx
import { Metadata } from 'next'

export const metadata: Metadata = {
  title: '${Title} | PromiseCard',
  description: '${Description}',
}

export default function ${Name}Page() {
  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold">${Title}</h1>
    </main>
  )
}
```

## 예시

입력: `/page about`

출력: `src/app/about/page.tsx`

입력: `/page cards/new`

출력: `src/app/cards/new/page.tsx`
