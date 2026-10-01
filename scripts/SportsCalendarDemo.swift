// Standalone screenshot helper; never include in the production app target.
#if targetEnvironment(simulator)
import UIKit
import EventKit
final class AppDelegate: UIResponder, UIApplicationDelegate {
 var window: UIWindow?
 let store = EKEventStore()
 func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  window = UIWindow(frame: UIScreen.main.bounds)
  let controller = UIViewController(); controller.view.backgroundColor = .white
  window?.rootViewController = controller; window?.makeKeyAndVisible()
  Task { @MainActor in
   do {
    guard try await store.requestFullAccessToEvents() else { throw NSError(domain:"Permission",code:1) }
    guard let local = store.sources.first(where: {$0.sourceType == .local}) else { throw NSError(domain:"No local source; refusing cloud writes",code:1) }
    let calendar = store.calendars(for: .event).first(where: {$0.title == "Sports" && $0.source.sourceIdentifier == local.sourceIdentifier}) ?? EKCalendar(for: .event, eventStore: store)
    calendar.title = "Sports"; calendar.source = local
    calendar.cgColor = UIColor(red:0.2,green:0.85,blue:0.4,alpha:1).cgColor
    try store.saveCalendar(calendar, commit:true)
    let day = Calendar.current.startOfDay(for:Date()).addingTimeInterval(86400)
    let games: [(String,Double,String,String)] = [
      ("Manchester United vs. Arsenal",12,"Old Trafford","Premier League\n\nBroadcast: NBC, Peacock"),
      ("Real Madrid vs. Barcelona",14.5,"Santiago Bernabéu","La Liga\n\nBroadcast: ESPN+"),
      ("Bayern Munich vs. Dortmund",17,"Allianz Arena","Bundesliga\n\nBroadcast: ESPN+"),
      ("LAFC vs. LA Galaxy",19.5,"BMO Stadium","MLS\n\nBroadcast: MLS Season Pass")]
    let existing = store.events(matching:store.predicateForEvents(withStart:day,end:day.addingTimeInterval(86400),calendars:[calendar]))
    for (i,g) in games.enumerated() {
     let marker = URL(string:"sports-marketing-demo://fixture/\(i)")!
     let e = existing.first(where:{$0.url == marker}) ?? EKEvent(eventStore:store)
     e.calendar=calendar;e.title=g.0;e.startDate=day.addingTimeInterval(g.1*3600);e.endDate=e.startDate.addingTimeInterval(7200)
     e.location=g.2;e.notes=g.3;e.url=marker;e.alarms=[EKAlarm(relativeOffset:-1800)]
     try store.save(e,span:.thisEvent,commit:true)
    }
    let proof = "Created/updated four fictional fixtures in local-only Sports calendar; no cloud source used."
    try proof.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("result.txt"),atomically:true,encoding:.utf8)
    print(proof)
   } catch { print("FAILED: \(error)") }
  }
  return true
 }
}
UIApplicationMain(CommandLine.argc,CommandLine.unsafeArgv,nil,NSStringFromClass(AppDelegate.self))

#else
#error("Calendar demo helper is Simulator-only")
#endif
