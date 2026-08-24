# 컨테이너가 구동중일 경우 삭제 후 다시 구동
docker stop mydb
docker stop board-web

docker rm mydb
docker rm board-web

docker network rm myapp-net
docker network create myapp-net
# MySql DB 컨테이너 구동
docker run -d --name mydb --network my-net -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:9.7

# temurin 25 jre 컨테이너 구동
docker run -d --name board-web -p 80:8080 --network my-net eclipse-temurin:25-jre-alpine tail -f //dev/null

# 로컬의 빌드된 최종 코드를 컨테이너에 복사(로그인한 계정의 홈디렉토리로 복사)
docker cp ./build/libs/spring-board-0.0.1-SNAPSHOT.jar board-web:/root/board.jar

# 컨테이너 내부의 대화형 쉘 접속 후 java 명령어로 board.jar 실행
docker exec -it board-web //bin/sh
cd ~
java -jar board.jar

#
./gradlew bootBuildImage --imageName=minkyolim/spring-board:1.0

#
./gradlew clean bootJar

#
docker build -t minkyolim/spring-board:1.0 .

# spring-board 배포
# 1. 기존 컨테이너를 중지 및 삭제
docker stop spring-board db-server
docker rm spring-board db-server

# 2. 네트워크 삭제
docker network rm myapp-net

# 3. 네트워크 생성
docker network create myapp-net

# 4 MySql 컨테이너 실행
docker run -d --name db-server --network myapp-net -p 3306:3306 \
  -v spring-board-db-data:/var/lib/mysql \
  -e MYSQL_DATABASE=board_db \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=Board123! \
  mysql:9.7

# uploads, logs 폴더 생성
mkdir -p uploads logs

# 5. 스프링 부트 컨테이너 실행
MSYS_NO_PATHCONV=1 docker run -d --name spring-board --network myapp-net -p 80:8080 \
-v "${PWD}/uploads:/app/uploads" \
-v "${PWD}/logs:/app/logs" \
-e SPRING_DATASOURCE_USERNAME=board-app \
-e SPRING_DATASOURCE_PASSWORD=Board123! \
-e SPRING_SQL_INIT_MODE=never \
minkyolim/spring-board:1.0

# 테스트 완료된 spring-board 이미지를 운영 서버에 배포하기 위해서 docker hub에 업로드
# 로그인
docker login

# docker hub에 이미지 업로드
docker push minkyolim/spring-board:1.0