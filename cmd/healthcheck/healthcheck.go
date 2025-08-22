package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"
)

func main() {
	var (
		url      = flag.String("url", "http://localhost:80/health", "Health check URL")
		timeout  = flag.Duration("timeout", 5*time.Second, "Request timeout")
		retries  = flag.Int("retries", 3, "Number of retries")
		interval = flag.Duration("interval", 1*time.Second, "Retry interval")
	)
	flag.Parse()

	client := &http.Client{Timeout: *timeout}
	
	for attempt := 0; attempt < *retries; attempt++ {
		if attempt > 0 {
			time.Sleep(*interval)
		}
		
		ctx, cancel := context.WithTimeout(context.Background(), *timeout)
		req, err := http.NewRequestWithContext(ctx, "GET", *url, nil)
		if err != nil {
			continue
		}
		
		resp, err := client.Do(req)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Attempt %d failed: %v\n", attempt+1, err)
			continue
		}
		
		resp.Body.Close()
		cancel()
		
		if resp.StatusCode >= 200 && resp.StatusCode < 400 {
			fmt.Printf("Health check passed: %s\n", resp.Status)
			os.Exit(0)
		}
		
		fmt.Fprintf(os.Stderr, "Attempt %d failed: status %s\n", attempt+1, resp.Status)
	}
	
	fmt.Fprintf(os.Stderr, "Health check failed after %d attempts\n", *retries)
	os.Exit(1)
}
