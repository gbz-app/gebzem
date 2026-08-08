package social

import (
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
)

func TestNilSliceEncodesAsNull(t *testing.T) {
	m := pgtype.NewMap()
	for _, f := range []struct {
		ad  string
		fmt int16
	}{{"text", pgtype.TextFormatCode}, {"binary", pgtype.BinaryFormatCode}} {
		var nilSlice []string
		buf, err := m.Encode(pgtype.UUIDArrayOID, f.fmt, nilSlice, nil)
		t.Logf("[%s] NIL   -> bufIsNil=%v len=%d err=%v", f.ad, buf == nil, len(buf), err)

		empty := []string{}
		buf2, err2 := m.Encode(pgtype.UUIDArrayOID, f.fmt, empty, nil)
		t.Logf("[%s] EMPTY -> bufIsNil=%v val=%q err=%v", f.ad, buf2 == nil, string(buf2), err2)

		dolu := []string{"6ba7b810-9dad-11d1-80b4-00c04fd430c8"}
		buf3, err3 := m.Encode(pgtype.UUIDArrayOID, f.fmt, dolu, nil)
		t.Logf("[%s] DOLU  -> bufIsNil=%v len=%d err=%v", f.ad, buf3 == nil, len(buf3), err3)
	}
}
