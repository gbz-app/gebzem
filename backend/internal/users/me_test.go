package users

import (
	"encoding/json"
	"strings"
	"testing"
)

// Gomme gercekten DUZ JSON uretiyor mu (ic ice nesne DEGIL)?
func TestMeYanitDuzJSON(t *testing.T) {
	b, err := json.Marshal(meYanit{userResp: userResp{ID: "u1", Name: "Ali"}, MedyaAcik: true})
	if err != nil {
		t.Fatal(err)
	}
	s := string(b)
	if !strings.Contains(s, `"id":"u1"`) {
		t.Fatalf("id duz degil: %s", s)
	}
	if !strings.Contains(s, `"media_acik":true`) {
		t.Fatalf("media_acik yok: %s", s)
	}
	if strings.Contains(s, `"userResp"`) {
		t.Fatalf("IC ICE nesne uretti — mevcut istemciler KIRILIR: %s", s)
	}
}
