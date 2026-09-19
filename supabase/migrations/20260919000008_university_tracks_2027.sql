-- 2027 수도권 대학/전형 선택 저장
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS admission_track TEXT;
CREATE INDEX IF NOT EXISTS students_admission_track_idx ON public.students(admission_track);
