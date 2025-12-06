#!/usr/bin/env swift

import Foundation

// RESEARCH-BACKED COMPREHENSIVE DATASET
// Based on ATUS 2024, Chronotype Research, and Age-Specific Productivity Patterns
//
// KEY RESEARCH FINDINGS:
// - Full-time workers: 8.1h work/day (8.4h weekdays, 5.6h weekends)
// - Leisure: 5.5h men, 4.7h women, 7.6h age 75+, 3.8h age 35-44
// - Household: 2h/day (2.7h women, 2.3h men)
// - Childcare: 2.5h/day (kids <6), 50min/day (kids 6-17)
// - Chronotype: Teens/20s = night owls, 40+ = morning types
// - Optimal work: Young adults 11AM-7PM, Mid-career 9AM-5PM, 55+ 8AM-12PM

enum CMActivityType: Int, CaseIterable {
    case unknown = 0
    case stationary = 1
    case walking = 2
    case running = 3
    case automotive = 4
    case cycling = 5
    var id: Int { rawValue }
}

enum Vibe: Int {
    case unknown = 0
    case sleep = 1
    case energetic = 2
    case focus = 3
    case commute = 4
    case chill = 5
    case morningRoutine = 6
    var id: Int { rawValue }
}

enum Confidence: Int {
    case low = 0
    case medium = 1
    case high = 2
}
enum DayType { case weekday, weekend, leave }
enum Chronotype { case lark, intermediate, owl }  // Morning person, neutral, night owl

struct ActivityBlock {
    let name: String
    let startMinute: Int
    let endMinute: Int
    let activity: CMActivityType
    let vibe: Vibe
    let confidence: Confidence

    var allocatedDuration: Double {
        let minutes =
            endMinute > startMinute
            ? Double(endMinute - startMinute)
            : Double((1440 - startMinute) + endMinute)
        return minutes * 60.0
    }

    func contains(_ minute: Int) -> Bool {
        if startMinute > endMinute {
            return minute >= startMinute || minute < endMinute
        }
        return minute >= startMinute && minute < endMinute
    }
}

struct Persona {
    let name: String
    let ageGroup: String
    let chronotype: Chronotype
    let weekdaySchedule: [ActivityBlock]
    let weekendSchedule: [ActivityBlock]
    let leaveSchedule: [ActivityBlock]

    func schedule(for dayType: DayType) -> [ActivityBlock] {
        switch dayType {
        case .weekday: return weekdaySchedule
        case .weekend: return weekendSchedule
        case .leave: return leaveSchedule
        }
    }
}

func time(_ hour: Int, _ minute: Int = 0) -> Int { hour * 60 + minute }

// PERSONA 1: Young Professional (25-35, Night Owl) - ATUS: 8.4h work, 3.8h leisure
let youngProfessionalOwl = Persona(
    name: "Young Professional (Night Owl)",
    ageGroup: "25-35",
    chronotype: .owl,
    weekdaySchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(1), endMinute: time(8), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 7h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(8), endMinute: time(9),
            activity: .stationary, vibe: .morningRoutine, confidence: .medium),
        ActivityBlock(
            name: "Breakfast", startMinute: time(9), endMinute: time(9, 30), activity: .stationary,
            vibe: .morningRoutine, confidence: .medium),
        ActivityBlock(
            name: "Commute", startMinute: time(9, 30), endMinute: time(10, 15),
            activity: .automotive, vibe: .commute, confidence: .high),  // 45min
        ActivityBlock(
            name: "Work (Morning - Low Energy)", startMinute: time(10, 30), endMinute: time(13),
            activity: .stationary, vibe: .focus, confidence: .medium),
        ActivityBlock(
            name: "Lunch", startMinute: time(13), endMinute: time(14), activity: .walking,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Work (Afternoon - Peak)", startMinute: time(14), endMinute: time(18, 30),
            activity: .stationary, vibe: .focus, confidence: .high),  // Peak productivity
        ActivityBlock(
            name: "Commute", startMinute: time(18, 30), endMinute: time(19, 15),
            activity: .automotive, vibe: .commute, confidence: .high),
        ActivityBlock(
            name: "Gym/Workout", startMinute: time(19, 30), endMinute: time(20, 30),
            activity: .running, vibe: .energetic, confidence: .high),
        ActivityBlock(
            name: "Dinner", startMinute: time(21), endMinute: time(22), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Entertainment/Social", startMinute: time(22), endMinute: time(0, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 2.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(0, 30), endMinute: time(1), activity: .stationary,
            vibe: .chill, confidence: .high),
    ],
    weekendSchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(2), endMinute: time(10), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 8h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(10), endMinute: time(11),
            activity: .stationary, vibe: .morningRoutine, confidence: .medium),
        ActivityBlock(
            name: "Brunch", startMinute: time(11), endMinute: time(12, 30), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Outing/Shopping", startMinute: time(13), endMinute: time(16), activity: .walking,
            vibe: .chill, confidence: .medium),  // 3h leisure
        ActivityBlock(
            name: "Cycling/Outdoor", startMinute: time(16, 30), endMinute: time(18),
            activity: .cycling, vibe: .energetic, confidence: .high),
        ActivityBlock(
            name: "Dinner Prep/Cooking", startMinute: time(19), endMinute: time(20, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h household
        ActivityBlock(
            name: "Social/Get Together", startMinute: time(21), endMinute: time(23, 30),
            activity: .walking, vibe: .chill, confidence: .high),  // 2.5h leisure
        ActivityBlock(
            name: "Entertainment", startMinute: time(23, 30), endMinute: time(1, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 2h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(1, 30), endMinute: time(2), activity: .stationary,
            vibe: .chill, confidence: .high),
    ],
    leaveSchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(2, 30), endMinute: time(11), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 8.5h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(11), endMinute: time(12),
            activity: .stationary, vibe: .morningRoutine, confidence: .medium),
        ActivityBlock(
            name: "Brunch", startMinute: time(12), endMinute: time(13), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Travel/Outing", startMinute: time(14), endMinute: time(19),
            activity: .automotive, vibe: .chill, confidence: .medium),  // 5h leisure/travel
        ActivityBlock(
            name: "Dinner", startMinute: time(20), endMinute: time(21, 30), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Cinema/Entertainment", startMinute: time(22), endMinute: time(1, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 3.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(1, 30), endMinute: time(2, 30),
            activity: .stationary, vibe: .chill, confidence: .high),
    ]
)

// PERSONA 2: Mid-Career Parent (35-45, Intermediate) - ATUS: 8.4h work, 2.5h childcare, 2.7h household
let midCareerParent = Persona(
    name: "Mid-Career Parent",
    ageGroup: "35-45",
    chronotype: .intermediate,
    weekdaySchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(23), endMinute: time(6), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 7h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(6), endMinute: time(6, 45),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Breakfast/Kids Prep", startMinute: time(6, 45), endMinute: time(7, 30),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),  // 45min childcare
        ActivityBlock(
            name: "School Drop-off", startMinute: time(7, 30), endMinute: time(8, 15),
            activity: .automotive, vibe: .commute, confidence: .high),  // 45min commute+childcare
        ActivityBlock(
            name: "Work (Morning - Peak)", startMinute: time(9), endMinute: time(12),
            activity: .stationary, vibe: .focus, confidence: .high),  // Peak 9-12
        ActivityBlock(
            name: "Lunch", startMinute: time(12), endMinute: time(13), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Work (Afternoon)", startMinute: time(13), endMinute: time(17),
            activity: .stationary, vibe: .focus, confidence: .high),
        ActivityBlock(
            name: "School Pickup/Commute", startMinute: time(17), endMinute: time(17, 45),
            activity: .automotive, vibe: .commute, confidence: .high),  // 45min
        ActivityBlock(
            name: "Kids Activities/Homework", startMinute: time(18), endMinute: time(19, 30),
            activity: .stationary, vibe: .chill, confidence: .medium),  // 1.5h childcare
        ActivityBlock(
            name: "Dinner Prep/Family Time", startMinute: time(19, 30), endMinute: time(21),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h household
        ActivityBlock(
            name: "Entertainment/TV", startMinute: time(21), endMinute: time(22, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(22, 30), endMinute: time(23), activity: .stationary,
            vibe: .chill, confidence: .high),
    ],
    weekendSchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(23, 30), endMinute: time(7, 30), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 8h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(7, 30), endMinute: time(8, 30),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Breakfast/Family Time", startMinute: time(8, 30), endMinute: time(10),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h childcare
        ActivityBlock(
            name: "Kids Sports/Activities", startMinute: time(10), endMinute: time(12),
            activity: .walking, vibe: .energetic, confidence: .medium),  // 2h childcare
        ActivityBlock(
            name: "Lunch", startMinute: time(12), endMinute: time(13), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Household Chores", startMinute: time(13), endMinute: time(15),
            activity: .stationary, vibe: .chill, confidence: .medium),  // 2h household
        ActivityBlock(
            name: "Family Outing", startMinute: time(15, 30), endMinute: time(18),
            activity: .walking, vibe: .chill, confidence: .high),  // 2.5h leisure
        ActivityBlock(
            name: "Dinner", startMinute: time(18, 30), endMinute: time(19, 30),
            activity: .stationary, vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Family Entertainment", startMinute: time(20), endMinute: time(22),
            activity: .stationary, vibe: .chill, confidence: .high),  // 2h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(22), endMinute: time(23, 30), activity: .stationary,
            vibe: .chill, confidence: .high),
    ],
    leaveSchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(0), endMinute: time(7, 30), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 7.5h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(7, 30), endMinute: time(8, 30),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Breakfast/Family Time", startMinute: time(8, 30), endMinute: time(10),
            activity: .stationary, vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Family Travel/Outing", startMinute: time(10, 30), endMinute: time(17),
            activity: .automotive, vibe: .chill, confidence: .medium),  // 6.5h leisure
        ActivityBlock(
            name: "Dinner", startMinute: time(18), endMinute: time(19), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Family Entertainment", startMinute: time(19, 30), endMinute: time(22),
            activity: .stationary, vibe: .chill, confidence: .high),  // 2.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(22), endMinute: time(0), activity: .stationary,
            vibe: .chill, confidence: .high),
    ]
)

// PERSONA 3: Senior Professional (55+, Morning Lark) - ATUS: Shorter hours, 7.6h leisure (75+)
let seniorProfessionalLark = Persona(
    name: "Senior Professional (Morning Lark)",
    ageGroup: "55+",
    chronotype: .lark,
    weekdaySchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(21, 30), endMinute: time(5, 30), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 8h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(5, 30), endMinute: time(6, 30),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Morning Walk/Exercise", startMinute: time(6, 30), endMinute: time(7, 30),
            activity: .walking, vibe: .energetic, confidence: .high),  // 1h exercise
        ActivityBlock(
            name: "Breakfast", startMinute: time(7, 30), endMinute: time(8, 15),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Commute", startMinute: time(8, 15), endMinute: time(8, 45),
            activity: .automotive, vibe: .commute, confidence: .high),  // 30min
        ActivityBlock(
            name: "Work (Morning - Peak)", startMinute: time(9), endMinute: time(12),
            activity: .stationary, vibe: .focus, confidence: .high),  // Peak 8-12
        ActivityBlock(
            name: "Lunch", startMinute: time(12), endMinute: time(13), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Work (Afternoon - Reduced)", startMinute: time(13), endMinute: time(15, 30),
            activity: .stationary, vibe: .focus, confidence: .medium),  // Shorter hours
        ActivityBlock(
            name: "Commute", startMinute: time(15, 30), endMinute: time(16), activity: .automotive,
            vibe: .commute, confidence: .high),
        ActivityBlock(
            name: "Tea/Relaxation", startMinute: time(16, 15), endMinute: time(17),
            activity: .stationary, vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Household/Gardening", startMinute: time(17), endMinute: time(18, 30),
            activity: .walking, vibe: .chill, confidence: .medium),  // 1.5h household
        ActivityBlock(
            name: "Dinner", startMinute: time(18, 30), endMinute: time(19, 30),
            activity: .stationary, vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Entertainment/Reading", startMinute: time(19, 30), endMinute: time(21),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(21), endMinute: time(21, 30), activity: .stationary,
            vibe: .chill, confidence: .high),
    ],
    weekendSchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(21), endMinute: time(6), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 9h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(6), endMinute: time(7),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Morning Walk", startMinute: time(7), endMinute: time(8, 30), activity: .walking,
            vibe: .energetic, confidence: .high),  // 1.5h exercise
        ActivityBlock(
            name: "Breakfast", startMinute: time(8, 30), endMinute: time(9, 30),
            activity: .stationary, vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Household/Gardening", startMinute: time(9, 30), endMinute: time(12),
            activity: .walking, vibe: .chill, confidence: .medium),  // 2.5h household
        ActivityBlock(
            name: "Lunch", startMinute: time(12), endMinute: time(13), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Social/Community Activity", startMinute: time(14), endMinute: time(17),
            activity: .walking, vibe: .chill, confidence: .high),  // 3h leisure
        ActivityBlock(
            name: "Tea Time", startMinute: time(17), endMinute: time(17, 30), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Dinner", startMinute: time(18), endMinute: time(19), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Entertainment/TV", startMinute: time(19), endMinute: time(20, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(20, 30), endMinute: time(21), activity: .stationary,
            vibe: .chill, confidence: .high),
    ],
    leaveSchedule: [
        ActivityBlock(
            name: "Sleep", startMinute: time(21), endMinute: time(6, 30), activity: .stationary,
            vibe: .sleep, confidence: .high),  // 9.5h
        ActivityBlock(
            name: "Wakeup/Morning Routine", startMinute: time(6, 30), endMinute: time(7, 30),
            activity: .stationary, vibe: .morningRoutine, confidence: .high),
        ActivityBlock(
            name: "Morning Walk", startMinute: time(7, 30), endMinute: time(9), activity: .walking,
            vibe: .energetic, confidence: .high),
        ActivityBlock(
            name: "Breakfast", startMinute: time(9), endMinute: time(10), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Travel/Sightseeing", startMinute: time(10, 30), endMinute: time(16),
            activity: .walking, vibe: .chill, confidence: .medium),  // 5.5h leisure
        ActivityBlock(
            name: "Tea Time", startMinute: time(16), endMinute: time(16, 30), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Relaxation", startMinute: time(16, 30), endMinute: time(18),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h leisure
        ActivityBlock(
            name: "Dinner", startMinute: time(18), endMinute: time(19), activity: .stationary,
            vibe: .chill, confidence: .high),
        ActivityBlock(
            name: "Entertainment", startMinute: time(19), endMinute: time(20, 30),
            activity: .stationary, vibe: .chill, confidence: .high),  // 1.5h leisure
        ActivityBlock(
            name: "Lay Down", startMinute: time(20, 30), endMinute: time(21), activity: .stationary,
            vibe: .chill, confidence: .high),
    ]
)

let personas = [youngProfessionalOwl, midCareerParent, seniorProfessionalLark]

func evaluate(vibe: Vibe, confidence: Confidence, duration: Double) -> (
    vibe: Vibe, probability: Double
) {
    var prob = 0.9
    prob *= confidence == .high ? 1.0 : (confidence == .medium ? 0.85 : 0.6)
    prob *= duration < 300 ? 0.7 : (duration > 1800 ? 1.1 : 1.0)
    return (vibe, min(1.0, prob))
}

// GENERATE RESEARCH-BACKED COMPREHENSIVE DATASET
func generateResearchDataset() {
    let baseTimestamp = Date(timeIntervalSince1970: 1_704_067_200)
    let calendar = Calendar.current

    print("timestamp,distance,activity,startTime,duration,hour,dayOfWeek,vibe,probability")

    for persona in personas {
        let dayTypes: [(DayType, Int)] = [(.weekday, 2), (.weekend, 1), (.leave, 7)]

        for (dayType, weekday) in dayTypes {
            let schedule = persona.schedule(for: dayType)

            // Sample every 15 minutes
            for minute in stride(from: 0, to: 1440, by: 15) {
                let hour = minute / 60
                let minuteInHour = minute % 60

                var components = calendar.dateComponents(
                    [.year, .month, .day], from: baseTimestamp)
                components.hour = hour
                components.minute = minuteInHour
                components.weekday = weekday

                guard let timestamp = calendar.date(from: components) else { continue }
                guard let block = schedule.first(where: { $0.contains(minute) }) else { continue }

                let duration = block.allocatedDuration

                // Realistic distance based on activity and duration
                let distance: Double
                let speed: Double
                switch block.activity {
                case .stationary, .unknown:
                    distance = 0.0
                    speed = 0.0
                case .walking:
                    speed = 1.4  // 1.4 m/s average
                    distance = speed * duration
                case .running:
                    speed = 3.0  // 3 m/s average
                    distance = speed * duration
                case .cycling:
                    speed = 5.5  // 5.5 m/s average
                    distance = speed * duration
                case .automotive:
                    speed = 12.0  // 12 m/s city average
                    distance = speed * duration
                }

                let result = evaluate(
                    vibe: block.vibe, confidence: block.confidence, duration: duration)
                let startTime = timestamp.timeIntervalSince1970 - duration

                print(
                    [
                        String(timestamp.timeIntervalSince1970),
                        String(distance),
                        String(block.activity.id),
                        String(startTime),
                        String(duration),
                        String(hour),
                        String(weekday),
                        String(result.vibe.id),
                        String(result.probability),
                    ].joined(separator: ","))
            }
        }
    }
}

generateResearchDataset()
