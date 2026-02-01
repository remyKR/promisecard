# 청첩장 도메인 지식

PromiseCard 모바일 청첩장 서비스의 도메인 지식입니다.

## 청첩장 필수 정보

| 필드 | 설명 | 타입 |
|------|------|------|
| `groom_name` | 신랑 이름 | string |
| `bride_name` | 신부 이름 | string |
| `wedding_date` | 결혼식 일시 | datetime |
| `venue_name` | 예식장 이름 | string |
| `venue_address` | 예식장 주소 | string |
| `venue_lat` | 위도 | number |
| `venue_lng` | 경도 | number |

## 청첩장 선택 정보

| 필드 | 설명 | 타입 |
|------|------|------|
| `gallery` | 커플 사진 | string[] |
| `greeting` | 인사말 | string |
| `groom_phone` | 신랑 연락처 | string |
| `bride_phone` | 신부 연락처 | string |
| `groom_father` | 신랑 아버지 | string |
| `groom_mother` | 신랑 어머니 | string |
| `bride_father` | 신부 아버지 | string |
| `bride_mother` | 신부 어머니 | string |
| `bank_accounts` | 축의금 계좌 | Account[] |
| `rsvp_enabled` | 참석 여부 기능 | boolean |

## 데이터베이스 스키마

```sql
-- 청첩장 테이블
CREATE TABLE invitation_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  template_id VARCHAR(50) NOT NULL,

  -- 필수 정보
  groom_name VARCHAR(50) NOT NULL,
  bride_name VARCHAR(50) NOT NULL,
  wedding_date TIMESTAMPTZ NOT NULL,
  venue_name VARCHAR(100) NOT NULL,
  venue_address TEXT NOT NULL,
  venue_lat DECIMAL(10, 8),
  venue_lng DECIMAL(11, 8),

  -- 선택 정보
  greeting TEXT,
  gallery JSONB DEFAULT '[]',
  bank_accounts JSONB DEFAULT '[]',
  rsvp_enabled BOOLEAN DEFAULT false,

  -- 메타
  status VARCHAR(20) DEFAULT 'draft',
  share_code VARCHAR(10) UNIQUE,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RSVP 테이블
CREATE TABLE rsvp_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID REFERENCES invitation_cards(id),
  guest_name VARCHAR(50) NOT NULL,
  attending BOOLEAN NOT NULL,
  guest_count INTEGER DEFAULT 1,
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 방명록 테이블
CREATE TABLE guestbook_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID REFERENCES invitation_cards(id),
  author_name VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 청첩장 상태 흐름

```
draft (임시저장)
   ↓
published (공개됨)
   ↓
archived (보관됨)
```

## 템플릿 종류

| ID | 이름 | 스타일 |
|----|------|--------|
| `classic-01` | 클래식 화이트 | 깔끔한 흰색 배경 |
| `modern-01` | 모던 미니멀 | 심플한 디자인 |
| `floral-01` | 플로럴 가든 | 꽃 장식 |
| `elegant-01` | 엘레강스 골드 | 고급스러운 금색 |
| `vietnam-01` | 베트남 전통 | 베트남 스타일 |

## 다국어 지원

- `ko`: 한국어 (기본)
- `vi`: 베트남어
- `en`: 영어

## 공유 URL 형식

```
https://promisecard.vn/card/{share_code}
```
