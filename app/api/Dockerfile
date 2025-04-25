# ビルドステージ
FROM adoptopenjdk:11-jdk-hotspot AS build
WORKDIR /app
COPY . .
RUN ./gradlew clean build -x test

# 実行ステージ
FROM adoptopenjdk:11-jre-hotspot
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/api/health || exit 1

# 実行ユーザーを設定（root以外）
RUN addgroup --system --gid 1001 appuser && \
    adduser --system --uid 1001 --gid 1001 appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
