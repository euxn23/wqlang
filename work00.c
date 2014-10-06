#include "stdio.h"
#include "string.h"

int main(void)
{
  /* m, nを宣言する場合 */
  /* char型の配列として文字列を宣言 */
  /* 最大128文字とする */
  // char text[128];
  // char patt[128];
  // int count = 0;

  // printf("Text: ");
  // scanf("%s", text);
  // printf("Pattern: ");
  // scanf("%s", patt);

  // const int m = strlen(text);
  // const int n = strlen(patt);

  // for (int i=0; i<m; i++) {
  //   if (text[i] == patt[0]) {
  //     for (int j=0; j<n; j++) {
  //       if (text[i+j] != patt[j]){
  //         break;
  //       }
  //     }

  //     /* patt[]の要素全てに対してマッチした場合のみ到達 */
  //     printf("match!: %d〜%d文字目\n", i+1, i+n);
  //     count++;
  //   }
  // }

  /* m, nを宣言しない場合 */
  /* char型の配列として文字列を宣言 */
  /* 最大128文字とする */
  char *text;
  char *patt;
  int count = 0;

  printf("Text: ");
  scanf("%s", text);
  printf("Pattern: ");
  scanf("%s", patt);

  int i = 0;
  int j;
  while (text[i] != '\0') {
    if (text[i] == patt[0]) {
      j=1;
      while (patt[j] != '\0') {
        if (text[i+j] != patt[j]) {
          break;
        }
        j++;
      }

      /* patt[]の要素全てに対してマッチした場合のみ到達 */
      printf("match!: %d〜%d文字目\n", i+1, i+j);
      count++;
    }
    i++;
  }

  printf("マッチ件数: %d件\n", count);
  return count;
}
