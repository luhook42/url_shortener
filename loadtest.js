import http from "k6/http";
import { SharedArray } from "k6/data";

const codes = new SharedArray("codes", function () {
  return JSON.parse(open("./codes.json"));
});

const HOT_COUNT = 5;      // first 5 codes are the "viral" links
const HOT_WEIGHT = 200;   // how many times more likely a hot code is to be picked

const weightedCodes = [];
codes.forEach((code, i) => {
  const repeat = i < HOT_COUNT ? HOT_WEIGHT : 1;
  for (let j = 0; j < repeat; j++) weightedCodes.push(code);
});

export const options = {
  vus: 50,        // 50 "virtual users" hammering the server concurrently
  duration: "30s",
};

export default function () {
  const isWrite = Math.random() < 0.001; // roughly 1 write per 1000 requests

  if (isWrite) {
    http.post("http://localhost:4567/links", {
      url: "https://example.com/new-" + Date.now(),
    });
  } else {
    const code = weightedCodes[Math.floor(Math.random() * weightedCodes.length)];
    http.get(`http://localhost:4567/${code}`, { redirects: 0 });
  }
}