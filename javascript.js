    function changeUrl(newPath) {
      history.pushState(null, '', newPath);
      // 선택적으로 페이지 내용을 변경할 수도 있습니다.
      console.log('주소가 변경되었습니다: ' + window.location.href);
    }