# Hello World - Java application (multi-stage: compile with JDK, run on JRE)
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY HelloWorld.java ./
RUN javac HelloWorld.java

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/HelloWorld.class ./
EXPOSE 8000
CMD ["java", "HelloWorld"]
