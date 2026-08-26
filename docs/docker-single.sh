# Spring Board 컨테이너 배포 및 구동

# 1. 기존 컨테이너, 이미지, 네트워크, 볼륨 목록 사전 조회
docker ps -a
docker images
docker network ls
docker volume ls

# 2. 모든 기존 컨테이너 강제 중지 및 전체 삭제
docker rm -f $(docker ps -aq) 2>/dev/null || true

# 3. 모든 기존 이미지 강제 전체 삭제
docker rmi -f $(docker images -q) 2>/dev/null || true

# 4. 모든 기존 Named Volumes 및 미사용 네트워크 전체 삭제
docker volume rm -f $(docker volume ls -q) 2>/dev/null || true
docker network rm -f $(docker network ls -q) 2>/dev/null || true

# 5. Spring Board 애플리케이션 전용 사용자 정의 네트워크 생성
docker network create board-net

# 6. DB 데이터 영속성 보존용 Named Volume 생성
docker volume create board-db-data

# 7. 게시판 첨부파일(uploads) 및 시스템 로그(logs) 바인드 마운트 전용 호스트 디렉터리 사전 생성
mkdir -p uploads logs

# 8. MySQL DB 컨테이너 백그라운드 구동, 볼륨 마운트 및 환경 변수 설정
docker run -d --name board-db \
  --network board-net \
  -p 3306:3306 \
  -v board-db-data:/var/lib/mysql \
  -e MYSQL_DATABASE=board_db \
  -e MYSQL_USER=board-app \
  -e MYSQL_PASSWORD=Board123! \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  mysql:9.7

# 9. Gradle 프로젝트 빌드 (단일 실행용 JAR 파일 생성)
./gradlew clean bootJar

# 10. 시맨틱 버저닝 적용 다중 태그 이미지 빌드 (1.0.0, 1.0, 1, latest 동시 지정)
docker build \
  -t minkyolim/spring-board:1.0.0 \
  -t minkyolim/spring-board:1.0 \
  -t minkyolim/spring-board:1 \
  -t minkyolim/spring-board:latest .

# 11. Docker Hub 인증 로그인
docker login

# 12. 빌드된 다중 태그 이미지를 Docker Hub 원격 레지스트리에 일괄 업로드
docker push --all-tags minkyolim/spring-board

# 13. Docker Hub 원격 레지스트리 다운로드 연동 테스트를 위해 로컬 빌드 이미지 완전 삭제
docker rmi minkyolim/spring-board:1.0.0 minkyolim/spring-board:1.0 minkyolim/spring-board:1 minkyolim/spring-board:latest

# 14. Docker Hub에서 원격 이미지를 자동 다운로드(pull)하여 Spring Board 애플리케이션 컨테이너 배포, Bind Mounts 및 포트 바인딩(80:8080)
MSYS_NO_PATHCONV=1 docker run -d --name board-app \
  --network board-net \
  -p 80:8080 \
  -v "${PWD}/uploads:/app/uploads" \
  -v "${PWD}/logs:/app/logs" \
  -e SPRING_DATASOURCE_URL="jdbc:mysql://board-db:3306/board_db?useSSL=false&allowPublicKeyRetrieval=true" \
  -e SPRING_DATASOURCE_USERNAME=board-app \
  -e SPRING_DATASOURCE_PASSWORD=Board123! \
  -e SPRING_SQL_INIT_MODE=always \
  minkyolim/spring-board:1.0

# 15. 실행 중인 컨테이너 정지 및 완전히 삭제
docker stop board-app board-db
docker rm board-app board-db

# 16. DB 컨테이너 재구동 (동일 Named Volume 마운트)
MSYS_NO_PATHCONV=1 docker run -d --name board-db \
  --network board-net \
  -p 3306:3306 \
  -v board-db-data:/var/lib/mysql \
  -e MYSQL_DATABASE=board_db \
  -e MYSQL_USER=board-app \
  -e MYSQL_PASSWORD=Board123! \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  mysql:9.7

# 17. Spring Board 컨테이너 재구동 (동일 Bind Mounts 마운트, 기존 DB 데이터 보존을 위해 -e SPRING_SQL_INIT_MODE=always 환경변수는 제거)
MSYS_NO_PATHCONV=1 docker run -d --name board-app \
  --network board-net \
  -p 80:8080 \
  -v "${PWD}/uploads:/app/uploads" \
  -v "${PWD}/logs:/app/logs" \
  -e SPRING_DATASOURCE_URL="jdbc:mysql://board-db:3306/board_db?useSSL=false&allowPublicKeyRetrieval=true" \
  -e SPRING_DATASOURCE_USERNAME=board-app \
  -e SPRING_DATASOURCE_PASSWORD=Board123! \
  minkyolim/spring-board:1.0

