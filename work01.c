#include "stdio.h"
#include "string.h"

void kmp_init(char* patt, int back[]);

void kmp_match(char* patt, char* text, int back[]);

int main(int argc, char *argv[])
{
  /* パターン、テキストを入力 */
  // char patt[1024];
  // char text[1024];
  // printf("Pattern: ");
  // scanf("%s", patt);
  // printf("Text: ");
  // scanf("%s", text);

  /* テストデータ */
  char patt[] = "abcabcab";
  //=> back = [-1, 0, 0, 0, 1, 2, 3, 4]
  char text[] = "abcababcabccabcabcacbacacbacbacabcabcbacbacbabcabcbabbbacbabcbacacbacabcabcaba";

  int m = strlen(patt);
  int back[m];
  kmp_init(patt, back);
  kmp_match(patt, text, back);
  return 0;
}

void kmp_init(char* patt, int back[]){
  int i = 0, j = -1;
  int m = strlen(patt);
  back[0] = -1;

  while(i < m-1) {
    if((j >= 0) && (patt[i] != patt[j])){
      j = back[j];
    }
    i++;
    j++;
    back[i] = j;
  }

  /* backの内容を確認 */
  int k;
  for (k=0;k<m;k++) {
    printf("back%d: %d\n", k, back[k]);
  }

}

void kmp_match(char* patt, char* text, int back[]){
  int i = 0, j = 0;
  int m = strlen(patt), n = strlen(text);

  while ((i < n) && (j < m)) {
    while ((j >= 0) && (text[i] != patt[j])) {
      j = back[j];
    }
    i++;
    j++;
  }

  if (j == m) {
    printf("パターンは含まれます: %d文字目～%d文字目\n", i-j+1, i-j+m);
  } else {
    printf("パターンは含まれませんでした\n");
  }

}
