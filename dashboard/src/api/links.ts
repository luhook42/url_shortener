import type { Link } from "../types/link";

interface ApiError {
  error: string;
}

export const BASE_URL: string =
  import.meta.env.VITE_API_URL ?? "http://localhost:4567";
const TOKEN: string | undefined = import.meta.env.VITE_API_TOKEN;

async function apiRequest<T>(
  url: string,
  options: RequestInit = {},
): Promise<T> {
  const response = await fetch(url, {
    ...options,
    headers: {
      ...options.headers,
      Authorization: `Bearer ${TOKEN}`,
    },
  });

  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      const err: ApiError = await response.json();
      if (err.error) message = err.error;
    } catch {
      // body was not JSON, keep the status-based message
    }
    throw new Error(message);
  }
  return response.json() as Promise<T>;
}

export function getLinks(): Promise<Link[]> {
  return apiRequest<Link[]>(`${BASE_URL}/links`);
}

export function createLink(url: string): Promise<Link> {
  return apiRequest<Link>(`${BASE_URL}/links`, {
    method: "POST",
    body: new URLSearchParams({ url }),
  });
}

export function updateLink(code: string, url: string): Promise<Link> {
  return apiRequest<Link>(`${BASE_URL}/links/${code}`, {
    method: "PUT",
    body: new URLSearchParams({ url }),
  });
}
