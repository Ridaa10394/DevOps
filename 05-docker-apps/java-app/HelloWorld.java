import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class HelloWorld {

    private static final int PORT = 8000;

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", PORT), 0);
        server.createContext("/", HelloWorld::handle);
        server.setExecutor(null);
        System.out.println("Java app listening on port " + PORT);
        server.start();
    }

    private static void handle(HttpExchange exchange) throws IOException {
        String html = """
                <html>
                  <head><title>Java Hello World</title></head>
                  <body style="font-family: sans-serif; text-align: center; padding-top: 80px;">
                    <h1>Hello World from Java</h1>
                    <p>Served by the JDK HttpServer inside a Docker container on port %d</p>
                  </body>
                </html>
                """.formatted(PORT);

        byte[] body = html.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
        exchange.sendResponseHeaders(200, body.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(body);
        }
    }
}
