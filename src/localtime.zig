const std = @import("std");

const TimeOffset = struct {
    from: i64,
    offset: i16,
};

const timeOffsets_Berlin = [_]TimeOffset{
    TimeOffset{ .from = 2140045200, .offset = 3600 }, // Sun Oct 25 01:00:00 2037
    TimeOffset{ .from = 2121901200, .offset = 7200 }, // Sun Mar 29 01:00:00 2037
    TimeOffset{ .from = 2108595600, .offset = 3600 }, // Sun Oct 26 01:00:00 2036
    TimeOffset{ .from = 2090451600, .offset = 7200 }, // Sun Mar 30 01:00:00 2036
    TimeOffset{ .from = 2077146000, .offset = 3600 }, // Sun Oct 28 01:00:00 2035
    TimeOffset{ .from = 2058397200, .offset = 7200 }, // Sun Mar 25 01:00:00 2035
    TimeOffset{ .from = 2045696400, .offset = 3600 }, // Sun Oct 29 01:00:00 2034
    TimeOffset{ .from = 2026947600, .offset = 7200 }, // Sun Mar 26 01:00:00 2034
    TimeOffset{ .from = 2014246800, .offset = 3600 }, // Sun Oct 30 01:00:00 2033
    TimeOffset{ .from = 1995498000, .offset = 7200 }, // Sun Mar 27 01:00:00 2033
    TimeOffset{ .from = 1982797200, .offset = 3600 }, // Sun Oct 31 01:00:00 2032
    TimeOffset{ .from = 1964048400, .offset = 7200 }, // Sun Mar 28 01:00:00 2032
    TimeOffset{ .from = 1950742800, .offset = 3600 }, // Sun Oct 26 01:00:00 2031
    TimeOffset{ .from = 1932598800, .offset = 7200 }, // Sun Mar 30 01:00:00 2031
    TimeOffset{ .from = 1919293200, .offset = 3600 }, // Sun Oct 27 01:00:00 2030
    TimeOffset{ .from = 1901149200, .offset = 7200 }, // Sun Mar 31 01:00:00 2030
    TimeOffset{ .from = 1887843600, .offset = 3600 }, // Sun Oct 28 01:00:00 2029
    TimeOffset{ .from = 1869094800, .offset = 7200 }, // Sun Mar 25 01:00:00 2029
    TimeOffset{ .from = 1856394000, .offset = 3600 }, // Sun Oct 29 01:00:00 2028
    TimeOffset{ .from = 1837645200, .offset = 7200 }, // Sun Mar 26 01:00:00 2028
    TimeOffset{ .from = 1824944400, .offset = 3600 }, // Sun Oct 31 01:00:00 2027
    TimeOffset{ .from = 1806195600, .offset = 7200 }, // Sun Mar 28 01:00:00 2027
    TimeOffset{ .from = 1792890000, .offset = 3600 }, // Sun Oct 25 01:00:00 2026
    TimeOffset{ .from = 1774746000, .offset = 7200 }, // Sun Mar 29 01:00:00 2026
    TimeOffset{ .from = 1761440400, .offset = 3600 }, // Sun Oct 26 01:00:00 2025
    TimeOffset{ .from = 1743296400, .offset = 7200 }, // Sun Mar 30 01:00:00 2025
    TimeOffset{ .from = 1729990800, .offset = 3600 }, // Sun Oct 27 01:00:00 2024
    TimeOffset{ .from = 1711846800, .offset = 7200 }, // Sun Mar 31 01:00:00 2024
    TimeOffset{ .from = 1698541200, .offset = 3600 }, // Sun Oct 29 01:00:00 2023
    TimeOffset{ .from = 1679792400, .offset = 7200 }, // Sun Mar 26 01:00:00 2023
    TimeOffset{ .from = 1667091600, .offset = 3600 }, // Sun Oct 30 01:00:00 2022
    TimeOffset{ .from = 1648342800, .offset = 7200 }, // Sun Mar 27 01:00:00 2022
    TimeOffset{ .from = 1635642000, .offset = 3600 }, // Sun Oct 31 01:00:00 2021
    TimeOffset{ .from = 1616893200, .offset = 7200 }, // Sun Mar 28 01:00:00 2021
    TimeOffset{ .from = 1603587600, .offset = 3600 }, // Sun Oct 25 01:00:00 2020
    TimeOffset{ .from = 1585443600, .offset = 7200 }, // Sun Mar 29 01:00:00 2020
    TimeOffset{ .from = 1572138000, .offset = 3600 }, // Sun Oct 27 01:00:00 2019
    TimeOffset{ .from = 1553994000, .offset = 7200 }, // Sun Mar 31 01:00:00 2019
    TimeOffset{ .from = 1540688400, .offset = 3600 }, // Sun Oct 28 01:00:00 2018
    TimeOffset{ .from = 1521939600, .offset = 7200 }, // Sun Mar 25 01:00:00 2018
    TimeOffset{ .from = 1509238800, .offset = 3600 }, // Sun Oct 29 01:00:00 2017
    TimeOffset{ .from = 1490490000, .offset = 7200 }, // Sun Mar 26 01:00:00 2017
    TimeOffset{ .from = 1477789200, .offset = 3600 }, // Sun Oct 30 01:00:00 2016
    TimeOffset{ .from = 0, .offset = 3600 }, //
};

fn findUnixOffset(unix: i64) i16 {
    for (timeOffsets_Berlin) |to| {
        if (to.from <= unix) {
            return to.offset;
        }
    }
    unreachable; // Tabelle muss erweitert werden!
}

fn findLocalOffset(local: i64) i16 {
    for (timeOffsets_Berlin) |to| {
        if (to.from + to.offset <= local) {
            return to.offset;
        }
    }
    unreachable; // Tabelle muss erweitert werden!
}

pub fn unix2local(unix: i64) i64 {
    const offset = findUnixOffset(unix);
    return unix + offset;
}

pub fn local2unix(local: i64) i64 {
    const offset = findLocalOffset(local);
    return local - offset;
}

pub const DateTime = struct {
    day: u8, month: u8, year: u16, hour: u8, minute: u8, second: u8
};

pub fn timestamp2DateTime(timestamp: i64) DateTime {

    // aus https://de.wikipedia.org/wiki/Unixzeit
    const unixtime = @intCast(u64, timestamp);
    const SEKUNDEN_PRO_TAG = 86400; //*  24* 60 * 60 */
    const TAGE_IM_GEMEINJAHR = 365; //* kein Schaltjahr */
    const TAGE_IN_4_JAHREN = 1461; //*   4*365 +   1 */
    const TAGE_IN_100_JAHREN = 36524; //* 100*365 +  25 - 1 */
    const TAGE_IN_400_JAHREN = 146097; //* 400*365 + 100 - 4 + 1 */
    const TAGN_AD_1970_01_01 = 719468; //* Tagnummer bezogen auf den 1. Maerz des Jahres "Null" */

    var tagN: u64 = TAGN_AD_1970_01_01 + unixtime / SEKUNDEN_PRO_TAG;
    var sekunden_seit_Mitternacht: u64 = unixtime % SEKUNDEN_PRO_TAG;
    var temp: u64 = 0;

    // Schaltjahrregel des Gregorianischen Kalenders:
    // Jedes durch 100 teilbare Jahr ist kein Schaltjahr, es sei denn, es ist durch 400 teilbar.
    temp = 4 * (tagN + TAGE_IN_100_JAHREN + 1) / TAGE_IN_400_JAHREN - 1;
    var jahr = @intCast(u16, 100 * temp);
    tagN -= TAGE_IN_100_JAHREN * temp + temp / 4;

    // Schaltjahrregel des Julianischen Kalenders:
    // Jedes durch 4 teilbare Jahr ist ein Schaltjahr.
    temp = 4 * (tagN + TAGE_IM_GEMEINJAHR + 1) / TAGE_IN_4_JAHREN - 1;
    jahr += @intCast(u16, temp);
    tagN -= TAGE_IM_GEMEINJAHR * temp + temp / 4;

    // TagN enthaelt jetzt nur noch die Tage des errechneten Jahres bezogen auf den 1. Maerz.
    var monat = @intCast(u8, (5 * tagN + 2) / 153);
    var tag = @intCast(u8, tagN - (@intCast(u64, monat) * 153 + 2) / 5 + 1);
    //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von Maerz bis Juli
    //  153 = 31+30+31+30+31 Tage fuer die 5 Monate von August bis Dezember
    //        31+28          Tage fuer Januar und Februar (siehe unten)
    //  +2: Justierung der Rundung
    //  +1: Der erste Tag im Monat ist 1 (und nicht 0).

    monat += 3; // vom Jahr, das am 1. Maerz beginnt auf unser normales Jahr umrechnen: */
    if (monat > 12) { // Monate 13 und 14 entsprechen 1 (Januar) und 2 (Februar) des naechsten Jahres
        monat -= 12;
        jahr += 1;
    }

    var stunde = @intCast(u8, sekunden_seit_Mitternacht / 3600);
    var minute = @intCast(u8, sekunden_seit_Mitternacht % 3600 / 60);
    var sekunde = @intCast(u8, sekunden_seit_Mitternacht % 60);

    return DateTime{ .day = tag, .month = monat, .year = jahr, .hour = stunde, .minute = minute, .second = sekunde };
}

pub fn printDateTime(dt: DateTime) void {
    std.debug.print("{:0<2}.{:0<2}.{:0<4} {:0<2}:{:0<2}:{:0<2}", .{
        dt.day,
        dt.month,
        dt.year,
        dt.hour,
        dt.minute,
        dt.second,
    });
}

pub fn printNowLocal() void {
    printDateTime(timestamp2DateTime(unix2local(std.time.timestamp())));
}

pub fn printNowUtc() void {
    printDateTime(timestamp2DateTime(std.time.timestamp()));
}

test "GMT and localtime" {
    // Summer, CEST
    std.testing.expect(unix2local(1598607147) == 1598607147 + 7200);
    std.testing.expectEqual(DateTime{ .year = 2020, .month = 8, .day = 28, .hour = 9, .minute = 32, .second = 27 }, timestamp2DateTime(1598607147));
    std.testing.expectEqual(DateTime{ .year = 2020, .month = 8, .day = 28, .hour = 11, .minute = 32, .second = 27 }, timestamp2DateTime(unix2local(1598607147)));
    std.testing.expect(local2unix(unix2local(1598607147)) == 1598607147);

    // Winter, CET
    std.testing.expect(unix2local(1604207167) == 1604207167 + 3600);
    std.testing.expectEqual(DateTime{ .year = 2020, .month = 11, .day = 1, .hour = 5, .minute = 6, .second = 7 }, timestamp2DateTime(1604207167));
    std.testing.expectEqual(DateTime{ .year = 2020, .month = 11, .day = 1, .hour = 6, .minute = 6, .second = 7 }, timestamp2DateTime(unix2local(1604207167)));
    std.testing.expect(local2unix(unix2local(1604207167)) == 1604207167);
}
