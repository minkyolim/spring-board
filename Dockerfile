FROM eclipse-temurin:25-jre
WORKDIR /app
COPY build/libs/*.jar spring-board.jar
ENTRYPOINT ["java", "-jar", "spring-board.jar"]
