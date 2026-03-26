-- template_id artık kullanıcının kendi görseli seçtiğinde NULL olabilir
ALTER TABLE public.generated_posts ALTER COLUMN template_id DROP NOT NULL;
