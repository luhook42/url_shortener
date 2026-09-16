import http from "k6/http";

export const options = {
  vus: 50,        // 50 "virtual users" hammering the server concurrently
  duration: "10s",
};

export default function () {
  http.get("http://localhost:4567/lYjLnNm", { redirects: 0 }); // use a real short code you created
}