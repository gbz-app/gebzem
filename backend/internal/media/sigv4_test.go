package media

import "testing"

func TestSelfTest(t *testing.T) {
	if err := SelfTest(); err != nil {
		t.Fatalf("SigV4 oz-testi TUTMADI: %v", err)
	}
}
