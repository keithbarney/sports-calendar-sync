import XCTest
@testable import SportsCalendarSync

final class ESPNDecodingTests: XCTestCase {
    func testCompetitorScoreObjectDoesNotBreakEventDecoding() throws {
        let json = """
        {
          "id": "761698",
          "date": "2026-08-01T23:30Z",
          "name": "LAFC at Vancouver Whitecaps",
          "competitions": [{
            "id": "761698",
            "date": "2026-08-01T23:30Z",
            "competitors": [{
              "id": "18966",
              "homeAway": "away",
              "team": {
                "id": "18966",
                "displayName": "LAFC",
                "logos": []
              },
              "score": {
                "displayValue": "1",
                "value": 1
              }
            }],
            "broadcasts": [{
              "market": {"id": "home"},
              "names": ["ESPN"]
            }]
          }]
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(ESPNEvent.self, from: json)

        XCTAssertEqual(event.id, "761698")
        XCTAssertEqual(event.competitions.first?.competitors.first?.team.id, "18966")
    }
}
