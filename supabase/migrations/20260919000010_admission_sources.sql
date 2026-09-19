-- Phase 5.1: 대학별 공식 입학처 URL 사전등록
CREATE TABLE IF NOT EXISTS public.admission_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admission_year INTEGER NOT NULL,
  university TEXT NOT NULL,
  official_url TEXT NOT NULL,
  guide_url TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(admission_year, university)
);

ALTER TABLE public.admission_sources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admission_sources_public_read ON public.admission_sources;
CREATE POLICY admission_sources_public_read ON public.admission_sources
  FOR SELECT TO anon, authenticated USING (active = TRUE);

CREATE OR REPLACE FUNCTION public.admin_get_admission_sources(p_year INTEGER DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  admission_year INTEGER,
  university TEXT,
  official_url TEXT,
  guide_url TEXT,
  source_url TEXT,
  notes TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF (SELECT email FROM auth.users WHERE id=auth.uid()) IS DISTINCT FROM public.phase5_admin_email() THEN
    RAISE EXCEPTION '관리자 권한이 없습니다.';
  END IF;
  RETURN QUERY
  SELECT s.id, s.admission_year, s.university, s.official_url, s.guide_url,
         COALESCE(NULLIF(s.guide_url,''), s.official_url) AS source_url, s.notes
  FROM public.admission_sources s
  WHERE s.active = TRUE AND (p_year IS NULL OR s.admission_year=p_year)
  ORDER BY s.university;
END; $$;

CREATE OR REPLACE FUNCTION public.set_updated_at_admission_sources()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at=now(); RETURN NEW; END; $$;
DROP TRIGGER IF EXISTS admission_sources_updated_at ON public.admission_sources;
CREATE TRIGGER admission_sources_updated_at BEFORE UPDATE ON public.admission_sources
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_admission_sources();

-- 공식 입학처 홈페이지를 기본 URL로 등록합니다.
-- 연도별 전형 안내 URL이 확정되면 guide_url만 해당 연도 페이지로 교체하면 됩니다.
INSERT INTO public.admission_sources(admission_year, university, official_url, guide_url, notes) VALUES
(2027,'아주대학교','https://www.iajou.ac.kr/main/','https://www.iajou.ac.kr/main/','공식 입학처 메인'),
(2027,'중앙대학교','https://admission.cau.ac.kr/main.do','https://admission.cau.ac.kr/main.do','공식 입학처 메인'),
(2027,'가톨릭대학교','https://ipsi.catholic.ac.kr/main.do','https://ipsi.catholic.ac.kr/main.do','공식 입학처 메인'),
(2027,'가천대학교','https://admission.gachon.ac.kr/admission/html/main/main.asp','https://admission.gachon.ac.kr/admission/html/main/main.asp','공식 입학처 메인'),
(2027,'이화여자대학교','https://admission.ewha.ac.kr/admission/html/main/main.asp','https://admission.ewha.ac.kr/admission/html/main/main.asp','공식 입학처 메인'),
(2027,'인하대학교','https://admission.inha.ac.kr/','https://admission.inha.ac.kr/','공식 입학처 메인'),
(2027,'단국대학교','https://ipsi.dankook.ac.kr/','https://ipsi.dankook.ac.kr/','공식 입학처 메인'),
(2027,'경희대학교','https://iphak.khu.ac.kr/main.do','https://iphak.khu.ac.kr/main.do','공식 입학처 메인'),
(2027,'국민대학교','https://admission.kookmin.ac.kr/main.php','https://admission.kookmin.ac.kr/main.php','공식 입학처 메인'),
(2027,'한국외국어대학교','https://adms.hufs.ac.kr/','https://adms.hufs.ac.kr/','공식 입학처 메인'),
(2027,'성균관대학교','https://admission.skku.edu/','https://admission.skku.edu/','공식 입학처 메인'),
(2027,'한양대학교','https://go.hanyang.ac.kr/main.do','https://go.hanyang.ac.kr/main.do','공식 입학처 메인'),
(2027,'건국대학교','https://enter.konkuk.ac.kr/','https://enter.konkuk.ac.kr/','서울캠퍼스 공식 입학처'),
(2027,'서울시립대학교','https://admission.uos.ac.kr/admissionNew/main.do','https://admission.uos.ac.kr/admissionNew/main.do','공식 입학처 메인'),
(2028,'아주대학교','https://www.iajou.ac.kr/main/','https://www.iajou.ac.kr/main/','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'중앙대학교','https://admission.cau.ac.kr/main.do','https://admission.cau.ac.kr/main.do','2028 대학입학전형시행계획 확인 가능'),
(2028,'가톨릭대학교','https://ipsi.catholic.ac.kr/main.do','https://ipsi.catholic.ac.kr/main.do','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'가천대학교','https://admission.gachon.ac.kr/admission/html/main/main.asp','https://admission.gachon.ac.kr/admission/html/main/main.asp','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'이화여자대학교','https://admission.ewha.ac.kr/admission/html/main/main.asp','https://admission.ewha.ac.kr/admission/html/main/main.asp','2028 입학전형 주요사항 안내 게시'),
(2028,'인하대학교','https://admission.inha.ac.kr/','https://admission.inha.ac.kr/','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'단국대학교','https://ipsi.dankook.ac.kr/','https://ipsi.dankook.ac.kr/','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'경희대학교','https://iphak.khu.ac.kr/main.do','https://iphak.khu.ac.kr/main.do','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'국민대학교','https://admission.kookmin.ac.kr/main.php','https://admission.kookmin.ac.kr/main.php','2028 대학입학전형계획 게시'),
(2028,'한국외국어대학교','https://adms.hufs.ac.kr/','https://adms.hufs.ac.kr/','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'성균관대학교','https://admission.skku.edu/','https://admission.skku.edu/','2028 입학전형 시행계획 게시'),
(2028,'한양대학교','https://go.hanyang.ac.kr/main.do','https://go.hanyang.ac.kr/main.do','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'건국대학교','https://enter.konkuk.ac.kr/','https://enter.konkuk.ac.kr/','2028 세부 전형 안내 페이지 확정 시 guide_url 업데이트'),
(2028,'서울시립대학교','https://admission.uos.ac.kr/admissionNew/main.do','https://admission.uos.ac.kr/admissionNew/main.do','2028 입학전형 기본계획 게시')
ON CONFLICT (admission_year, university) DO UPDATE SET
 official_url=EXCLUDED.official_url,
 guide_url=EXCLUDED.guide_url,
 notes=EXCLUDED.notes,
 active=TRUE,
 updated_at=now();
