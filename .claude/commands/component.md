# Component Generator

`$ARGUMENTS` 이름으로 React 컴포넌트를 생성해주세요.

## 생성 위치

- UI 컴포넌트: `src/components/ui/`
- 기능 컴포넌트: `src/components/features/`

## 규칙

1. TypeScript 사용 (.tsx)
2. 함수형 컴포넌트
3. Tailwind CSS 스타일링
4. Props 타입 정의 필수

## 템플릿

```tsx
type ${Name}Props = {
  // props 정의
}

export default function ${Name}({ }: ${Name}Props) {
  return (
    <div className="">
      {/* 컴포넌트 내용 */}
    </div>
  )
}
```

## 예시

입력: `/component Button`

출력: `src/components/ui/Button.tsx`
