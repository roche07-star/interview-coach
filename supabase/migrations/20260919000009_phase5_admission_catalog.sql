-- Phase 5: 연도별 대학 전형 카탈로그
CREATE TABLE IF NOT EXISTS public.admission_tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admission_year INTEGER NOT NULL,
  university TEXT NOT NULL,
  track TEXT NOT NULL,
  department_scope TEXT,
  document_criteria TEXT,
  interview_criteria TEXT,
  method TEXT,
  source_url TEXT,
  source_title TEXT,
  source_published_at DATE,
  source_checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  import_status TEXT NOT NULL DEFAULT 'draft' CHECK (import_status IN ('draft','published','archived','error')),
  import_notes TEXT,
  raw_source_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(admission_year, university, track)
);

ALTER TABLE public.students ADD COLUMN IF NOT EXISTS admission_year INTEGER DEFAULT 2027;
CREATE INDEX IF NOT EXISTS admission_tracks_year_university_idx ON public.admission_tracks(admission_year, university);
CREATE INDEX IF NOT EXISTS admission_tracks_status_idx ON public.admission_tracks(import_status);
CREATE INDEX IF NOT EXISTS students_admission_year_idx ON public.students(admission_year);

ALTER TABLE public.admission_tracks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admission_tracks_public_read ON public.admission_tracks;
CREATE POLICY admission_tracks_public_read ON public.admission_tracks FOR SELECT TO anon, authenticated USING (import_status='published');

CREATE OR REPLACE FUNCTION public.phase5_admin_email()
RETURNS TEXT LANGUAGE sql STABLE AS $$ SELECT 'ziron7@gmail.com'::text $$;

CREATE OR REPLACE FUNCTION public.admin_get_admission_tracks(p_year INTEGER DEFAULT NULL)
RETURNS SETOF public.admission_tracks
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF (SELECT email FROM auth.users WHERE id=auth.uid()) IS DISTINCT FROM public.phase5_admin_email() THEN
    RAISE EXCEPTION '관리자 권한이 없습니다.';
  END IF;
  RETURN QUERY SELECT * FROM public.admission_tracks
   WHERE (p_year IS NULL OR admission_year=p_year)
   ORDER BY admission_year DESC, university, track;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_publish_admission_track(p_id UUID, p_status TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF (SELECT email FROM auth.users WHERE id=auth.uid()) IS DISTINCT FROM public.phase5_admin_email() THEN
    RAISE EXCEPTION '관리자 권한이 없습니다.';
  END IF;
  IF p_status NOT IN ('draft','published','archived','error') THEN RAISE EXCEPTION '잘못된 상태입니다.'; END IF;
  UPDATE public.admission_tracks SET import_status=p_status, updated_at=now() WHERE id=p_id;
  RETURN FOUND;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_delete_admission_track(p_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF (SELECT email FROM auth.users WHERE id=auth.uid()) IS DISTINCT FROM public.phase5_admin_email() THEN
    RAISE EXCEPTION '관리자 권한이 없습니다.';
  END IF;
  DELETE FROM public.admission_tracks WHERE id=p_id;
  RETURN FOUND;
END; $$;

-- Phase 4에서 사용하던 2027 데이터 seed. 기존 데이터가 있으면 덮어쓰지 않는다.
INSERT INTO public.admission_tracks(admission_year,university,track,document_criteria,interview_criteria,method,import_status,import_notes)
VALUES
(2027,'아주대학교','학생부종합 ACE전형','학업역량·진로역량·공동체역량을 바탕으로 교과와 비교과를 균형 있게 평가','제출서류 기반 서류확인 면접','1단계 서류 100%, 2단계 1단계 70% + 면접 30%','published','Phase 4 기존 데이터 이관'),
(2027,'중앙대학교','학생부종합 탐구형인재','학업역량·진로역량·공동체역량을 중심으로 평가','학업준비도·전공(계열) 적합성·의사소통능력 및 인성을 확인하는 학생부 기반 개인별 심층면접','1단계 서류평가 후 2단계 면접','published','Phase 4 기존 데이터 이관'),
(2027,'가톨릭대학교','학생부종합 학교장추천','학업역량 40%·진로역량 35%·공동체역량 25%','제출서류 기반 면접','1단계 서류평가 후 2단계 면접','published','Phase 4 기존 데이터 이관'),
(2027,'가천대학교','학생부종합 바람개비전형','학교생활기록부를 중심으로 학업역량·진로역량·공동체역량을 종합적으로 평가','학생부 기반 면접','2027학년도 전형계획 기준 적용','published','Phase 4 기존 데이터 이관; 모집단위별 공식자료 재검수 권장'),
(2027,'이화여자대학교','학생부종합 미래인재전형','학업역량·학교활동의 우수성·발전가능성','제출서류 기반 일반면접: 학업역량·진로역량·발전가능성','서류 70% + 면접 30%','published','Phase 4 기존 데이터 이관'),
(2027,'인하대학교','학생부종합 인하미래인재(면접형)','기초학업역량 30%·진로탐구역량 50%·공동체역량 20%','학교생활기록부 기반 개별 질의응답','1단계 서류 100%, 2단계 1단계 70% + 면접 30%','published','Phase 4 기존 데이터 이관'),
(2027,'단국대학교','학생부종합 DKU인재(면접형)','학업역량·진로역량·공동체역량','학교생활기록부 기반 질의응답: 진로역량 50%·발전가능성 30%·공동체역량 20%','1단계 서류 100%, 2단계 1단계 70% + 면접 30%','published','Phase 4 기존 데이터 이관'),
(2027,'경희대학교','학생부종합 네오르네상스전형','학업역량·진로역량·공동체역량','전 계열 서류확인 면접','1단계 서류 100%, 2단계 1단계 70% + 면접 30%','published','Phase 4 기존 데이터 이관'),
(2027,'국민대학교','학생부종합 국민프런티어전형','학교생활기록부 정성 종합평가','서류기반 맞춤형 개별면접. 학교생활 충실성, 도전정신, 자기주도적 성장 등을 확인','1단계 서류 100%, 2단계 1단계 70% + 면접 30%','published','Phase 4 기존 데이터 이관'),
(2027,'한국외국어대학교','학생부종합 면접형','학교생활기록부 기반 서류평가','진로개발역량·협력적소통역량','1단계 서류평가 후 면접','published','Phase 4 기존 데이터 이관; 모집단위별 공식자료 재검수 권장'),
(2027,'성균관대학교','학생부종합 성균인재','학업수월성·학업충실성·탐구확장성·탐구주도성·미래성장성·공동체의식','블라인드 인·적성면접: 소통능력·갈등관리·책임감 등 사회적 특성과 전공 관심·열의 확인','대학 공식 2027 전형 평가기준 반영','published','Phase 4 기존 데이터 이관'),
(2027,'한양대학교','학생부종합 면접형','학생부 전 영역 정성평가','모집단위별 면접 방식 상이','모집단위별 전형계획 확인','published','Phase 4 기존 데이터 이관; 모집단위별 공식자료 재검수 권장'),
(2027,'건국대학교','학생부종합 KU자기추천','학교생활기록부 기반 종합평가','서류 기반 면접','대학 공식 2027 전형계획 기준','published','Phase 4 기존 데이터 이관; 공식자료 재검수 권장'),
(2027,'서울시립대학교','학생부종합전형','학교생활기록부 기반 종합평가','모집단위별 전형계획 확인','모집단위별 전형계획 확인','published','Phase 4 기존 데이터 이관; 모집단위별 공식자료 재검수 권장')
ON CONFLICT (admission_year, university, track) DO NOTHING;

CREATE OR REPLACE FUNCTION public.set_updated_at_admission_tracks()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at=now(); RETURN NEW; END; $$;
DROP TRIGGER IF EXISTS admission_tracks_updated_at ON public.admission_tracks;
CREATE TRIGGER admission_tracks_updated_at BEFORE UPDATE ON public.admission_tracks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_admission_tracks();
