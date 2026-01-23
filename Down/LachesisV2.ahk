#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-AddResource M:\OneDrive\Personalize\MyIcons\Lachesisv02.ico, 101
;@Ahk2Exe-AddResource M:\OneDrive\Personalize\MyIcons\Hand.ico, 102
; 상수
MaxInterval := 2000   ; 스크롤 간 평균 시간 간격 (ms)
DefaultInterval := 1500 ; 스크롤 히스토리 초기값 (ms)
DebugMode := False

; 스크롤 처리에 사용할 전역 변수 선언
global SHCnt := 0            ; 총 스크롤 이벤트 수를 저장
global AvgInterval := 1500   ; 스크롤 간 평균 시간 간격 (ms)
global Cnt := 0              ; 스크롤 가속이 너무 빨라 짝수때만 세어 가속올리는 카운트
global ScrollHistory := Array() ; 최근 스크롤 간격을 저장하는 배열
global TurboMode := true     ; 터보 모드 상태를 저장 (true: ON, false: OFF)
global LastScrollTime := 0   ; 마지막 스크롤 시간을 저장
global WheelSpeed := 1       ; 스크롤 가속도 레벨
global MaxScrolls := 18      ; 최대 스크롤 횟수 제한

; Win+Esc: DrawBox 창 닫기
!#RButton::
{
    ; DrawBox 창이 존재하는지 확인
    winId := WinExist("DrawBox")
    if winId
        WinClose("ahk_id " winId) ; DrawBox 창 닫기
    return
}

; Win+Alt+마우스 가운데 버튼: DrawBoxCS 실행 또는 활성화
^#MButton::
{
    ; DrawBoxCS 프로그램 실행 또는 기존 창 활성화
    ActivateOrRun("M:\OneDrive\SourceCode\Bin\DrawBoxCS.lnk", false)
}

; Win+Shift+Numpad0: RamSpace 폴더 열기 또는 활성화
^#Numpad0::
{
    ; RamSpace 폴더 열기 또는 기존 창 활성화
    ActivateOrRun("R:\RamSpace\", true)
}

; Win+End 또는 F2: 스크립트 종료
#End::    
{
    ; 종료 메시지 툴팁 표시
    QuickToolTip("Lachesis: Bye Bye~", 500)
    Sleep(500) ; 툴팁 표시 후 0.5초 대기
    ExitApp()  ; 스크립트 종료
}

; Win+Pause: 터보 모드 토글
#Pause::
{
    global TurboMode
    TurboMode := !TurboMode ; 터보 모드 상태 전환 (ON/OFF)
    try {
        ; 터보 모드 상태에 따라 시스템 트레이 아이콘 변경
        TraySetIcon(TurboMode ? "M:\OneDrive\Personalize\MyIcons\CuteIcon.Ico" : "M:\OneDrive\Personalize\MyIcons\Hand.ico")
        TraySetIcon(A_ScriptFullPath,TurboMode ? -101 : -102, true)
    } catch {
        ; 아이콘 파일이 없으면 기본 아이콘 유지
    }
    ; 터보 모드 상태를 툴팁으로 표시
    QuickToolTip(TurboMode ? "터보 모드 ON" : "터보 모드 OFF", 500)
}

; Win+z: 볼륨 믹서 열기
#z::
{
    ; 볼륨 믹서 실행 (기본 볼륨 100%로 설정)
    Run("SndVol.exe -f 111111111")
}

; 마우스 휠 업/다운: 동적 스크롤 처리
WheelUp::
WheelDown::
{
    global SHCnt, AvgInterval, ScrollHistory, TurboMode, LastScrollTime, Cnt, MaxScrolls, WheelSpeed

    ; 터보 모드 OFF 시 단일 스크롤 전송
    if (!TurboMode) {
        Send("{" . A_ThisHotkey . "}") ; 현재 핫키(휠 업/다운) 전송
        return
    }

    ; 마지막 스크롤 이후 경과 시간 계산
    CurrentInterval := LastScrollTime > 0 ? A_TickCount - LastScrollTime : DefaultInterval
    LastScrollTime := A_TickCount ; 현재 시간으로 마지막 스크롤 시간 갱신
    
    ; 반대방향 스크롤이거나 긴 공백 후 스크롤 시 히스토리 초기화
    if (A_PriorHotkey != A_ThisHotkey || CurrentInterval >= DefaultInterval) {
        if (ScrollHistory.Length > 1) {
            ScrollHistory.RemoveAt(1, ScrollHistory.Length) ; 스크롤 히스토리 초기화
            ScrollHistory.Push(DefaultInterval) ; 초기 간격 추가
        }
        WheelSpeed := 1 ; 스크롤 속도 초기화
        AvgInterval := CurrentInterval ; 평균 간격을 현재 간격으로 설정
        Send("{" . A_ThisHotkey . "}") ; 단일 스크롤 전송
        return
    }

    ; 스크롤 간격 총합 및 횟수 계산
    TotalInterval := 0
    SHCnt := 0
    Loop ScrollHistory.Length {
        idx := ScrollHistory.Length - A_index +1
        if (TotalInterval < MaxInterval) {
            TotalInterval += ScrollHistory[idx] ; 간격 누적
            SHCnt++ ; 스크롤 횟수 증가
        } else {
            ScrollHistory.RemoveAt(1, idx) ; 오래된 히스토리 제거
            break
        }
    }
    ScrollHistory.Push(CurrentInterval) ; 현재 간격 추가
    AvgInterval := (SHCnt > 0) ? Floor(TotalInterval / SHCnt) : CurrentInterval ; 평균 간격 계산

;#############################################################################################
; 스크롤 속도 결정
;#############################################################################################
    if (ScrollHistory.Length < 7 || CurrentInterval > 500) {
        WheelSpeed := 1
    } else if (ScrollHistory.Length < 13) {
        WheelSpeed := Max(2, Floor(ScrollHistory.Length/3) )
    } else if (WheelSpeed < 28) {
        if(!Mod(Cnt++,4)) {
            WheelSpeed++
            Cnt:= Cnt>1000 ? 0: Cnt
        }
    }
    if DebugMode
    {
        ; 스크롤 정보 툴팁 표시
        output := "Tot: " . TotalInterval . ", Spd: " . WheelSpeed . "`n"
        for i, value in ScrollHistory {
            output .= i ": " . value . "`n"
        }
        QuickToolTip(output, 1000)
    }
    ; 계산된 속도로 스크롤 실행
    MouseClick(A_ThisHotkey, , , WheelSpeed)
}

; 툴팁 표시 함수
QuickToolTip(text, delay) {
    ToolTip(text) ; 툴팁 표시
    SetTimer(RemoveToolTip, -delay) ; 지정된 시간 후 툴팁 제거
    RemoveToolTip() {
        ToolTip() ; 툴팁 제거
    }
}

; 창을 활성화하거나 응용 프로그램/폴더 실행
ActivateOrRun(target, isFolder := false) {
    if isFolder {
        ; 파일 탐색기 창 확인 (CabinetWClass 또는 ExploreWClass)
        winTitle := target
        winId := WinExist("ahk_class CabinetWClass ahk_exe explorer.exe", winTitle)
        if winId {
            WinActivate winId ; 기존 창 활성화
        } else {
            Run target ; 폴더 실행
        }
    } else {
        ; 응용 프로그램 창 확인 및 실행
        winId := WinExist(target)
        if winId {
            WinActivate winId ; 기존 창 활성화
        } else {
            Run target ; 응용 프로그램 실행
        }
    }
}
