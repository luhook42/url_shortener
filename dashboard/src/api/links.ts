import type { Link } from "../types/link";

interface ErrorBody {
  error: string;
}

// Thrown for any non-2xx response, so callers can check the status (e.g. 401).
export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export const BASE_URL: string =
  import.meta.env.VITE_API_URL ?? "http://localhost:4567";

export async function apiRequest<T>(
  url: string,
  options: RequestInit = {},
): Promise<T> {
  const response = await fetch(url, {
    ...options,
    // The session cookie identifies you. No token lives in this code anymore.
    credentials: "include",
  });

  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      const err: ErrorBody = await response.json();
      if (err.error) message = err.error;
    } catch {
      // body was not JSON (e.g. a 429), keep the status-based message
    }
    throw new ApiError(message, response.status);
  }
  if (response.status === 204) return undefined as T; // sign-out has no body
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
