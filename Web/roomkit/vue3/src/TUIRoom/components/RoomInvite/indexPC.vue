<template>
  <div class="invite-container">
    <div
      v-for="(item, index) in invitationFeatureDetails"
      :key="index"
      class="invite-item"
      @click="item.function()"
    >
      <TUIIcon size="16" :icon="item.icon" />
      <span class="invite-title">{{ t(item.text) }}</span>
    </div>
    <Contacts
      :visible="showContacts"
      :contacts="contacts"
      :disabled-list="remoteEnteredUserList"
      @input="showContacts = $event"
      @confirm="contactsConfirm"
    />
    <Dialog
      v-model="isShowRoomShareForm"
      :title="
        t('sb invites you to join the conference', { name: userName || userId })
      "
      :modal="true"
      :show-close="true"
      :close-on-click-modal="true"
      width="540px"
      :append-to-body="true"
      :title-icon="IconSuccess"
    >
      <div class="invite-member">
        <div
          v-for="item in inviteInfoList"
          :key="item.title"
          v-show="item.isVisible"
        >
          <div class="invite-member-container">
            <span class="invite-member-title">{{ t(item.title) }}</span>
            <span class="invite-member-content" :title="item.content">
              {{ item.content }}
            </span>
            <IconCopy
              class="copy"
              v-if="item.isShowCopyIcon"
              @click="onCopy(item.content)"
            />
          </div>
        </div>
      </div>
      <template #footer>
        <span>
          <TUIButton
            @click="copyRoomIdAndRoomLink()"
            type="primary"
            style="min-width: 88px"
          >
            {{ t('Copy the conference number and link') }}
          </TUIButton>
        </span>
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import useRoomInviteControl from './useRoomInviteHooks';
import {
  TUIButton,
  TUIIcon,
  IconSuccess,
  IconCopy,
} from '@tencentcloud/uikit-base-component-vue3';
import Contacts from '../ScheduleConference/Contacts.vue';
import Dialog from '../common/base/Dialog';
const {
  t,
  invitationFeatureDetails,
  showContacts,
  contactsConfirm,
  contacts,
  remoteEnteredUserList,
  isShowRoomShareForm,
  userId,
  userName,
  inviteInfoList,
  onCopy,
  copyRoomIdAndRoomLink,
} = useRoomInviteControl();
</script>

<style lang="scss" scoped>
.invite-container {
  position: absolute;
  right: -25px;
  bottom: 72px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100px;
  padding: 5px 10px;
  border-radius: 15px;
  background-color: var(--bg-color-dialog);
  box-shadow: 0 -8px 30px var(--uikit-color-black-8);

  .invite-item {
    display: flex;
    align-items: center;
    margin-top: 5px;
    cursor: pointer;
    .invite-title {
      padding-left: 5px;
      font-family: 'PingFang SC';
      font-size: 12px;
      font-weight: 400;
      line-height: 20px;
      text-align: left;
    }
  }
}

.invite-member {
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin-top: 10px;

  .invite-member-container {
    display: flex;
    align-items: center;
    min-width: 400px;
    font-size: 14px;
    font-weight: 400;
    line-height: 20px;
    color: var(--text-color-secondary);

    .invite-member-title {
      flex-basis: 18%;
    }

    .invite-member-content {
      max-width: 360px;
      overflow: hidden;
      font-weight: 500;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .copy {
      margin-left: 8px;
      cursor: pointer;
      color: var(--text-color-link);
    }
  }
}
</style>
